# Importa anotaciones diferidas para mantener compatibilidad de tipos.
from __future__ import annotations

# Importa hashlib para calcular y validar hashes SHA-256.
import hashlib
# Importa json para validar manifiestos y configuraciones JSON.
import json
# Importa re para extraer frontmatter mínimo sin dependencias externas.
import re
# Importa sys para devolver un código de salida adecuado.
import sys
# Importa Path para operar con rutas de forma portable.
from pathlib import Path

# Define una expresión regular conservadora para localizar el frontmatter YAML inicial.
FRONTMATTER_RE = re.compile(r"\A---\s*\n(?P<body>.*?)\n---\s*\n", re.DOTALL)
# Define una expresión regular para extraer claves YAML simples obligatorias de una línea.
KEY_RE = re.compile(r"^(?P<key>name|description):\s*(?P<value>.+?)\s*$", re.MULTILINE)
# Define el formato esperado para nombres de skills y plugin en kebab-case.
KEBAB_RE = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*")
# Define el formato exacto de un hash SHA-256 hexadecimal en minúsculas.
SHA256_RE = re.compile(r"[0-9a-f]{64}")
# Define el formato exacto de un commit Git SHA-1 completo en minúsculas.
GIT_SHA_RE = re.compile(r"[0-9a-f]{40}")

# Calcula SHA-256 de un fichero sin cargarlo completo en memoria.
def sha256_file(path: Path) -> str:
    # Crea el objeto de digest SHA-256.
    digest = hashlib.sha256()
    # Abre el fichero en modo binario.
    with path.open("rb") as handle:
        # Lee bloques de un MiB hasta alcanzar EOF.
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            # Incorpora cada bloque al digest.
            digest.update(chunk)
    # Devuelve el hash hexadecimal final.
    return digest.hexdigest()

# Valida un SKILL.md y devuelve su nombre junto con los errores detectados.
def validate_skill(skill_file: Path) -> tuple[str | None, list[str]]:
    # Inicializa la colección de errores de la skill.
    errors: list[str] = []
    # Lee el documento como UTF-8.
    text = skill_file.read_text(encoding="utf-8")
    # Busca el frontmatter inicial.
    match = FRONTMATTER_RE.search(text)
    # Comprueba que exista frontmatter.
    if match is None:
        # Registra el fallo estructural.
        errors.append(f"{skill_file}: missing YAML frontmatter")
        # Devuelve sin nombre porque no se puede validar identidad.
        return None, errors
    # Extrae las claves simples relevantes.
    values = {
        # Conserva la clave y limpia comillas exteriores razonables.
        item.group("key"): item.group("value").strip().strip('"\'')
        # Recorre todas las coincidencias dentro del frontmatter.
        for item in KEY_RE.finditer(match.group("body"))
    }
    # Obtiene el nombre declarado.
    name = values.get("name")
    # Comprueba la presencia de name.
    if not name:
        # Registra ausencia de identidad.
        errors.append(f"{skill_file}: missing name")
    # Comprueba la presencia de description.
    if not values.get("description"):
        # Registra ausencia de descripción para discovery.
        errors.append(f"{skill_file}: missing description")
    # Valida kebab-case cuando existe nombre.
    if name and KEBAB_RE.fullmatch(name) is None:
        # Registra un nombre incompatible con el convenio esperado.
        errors.append(f"{skill_file}: name is not kebab-case: {name}")
    # Devuelve el nombre y los errores acumulados.
    return name, errors

# Parsea el manifiesto SHA-256 del bundle.
def parse_manifest(manifest_file: Path) -> tuple[dict[str, str], list[str]]:
    # Inicializa errores del manifiesto.
    errors: list[str] = []
    # Inicializa el mapa ruta -> hash esperado.
    entries: dict[str, str] = {}
    # Recorre cada línea preservando diagnóstico por número.
    for line_number, raw_line in enumerate(manifest_file.read_text(encoding="utf-8").splitlines(), start=1):
        # Elimina espacios exteriores.
        line = raw_line.strip()
        # Ignora líneas vacías para tolerar una nueva línea final.
        if not line:
            # Continúa con la siguiente entrada.
            continue
        # Divide una sola vez entre hash y ruta.
        parts = line.split(maxsplit=1)
        # Comprueba que existan ambos componentes.
        if len(parts) != 2:
            # Registra sintaxis inválida.
            errors.append(f"MANIFEST.sha256:{line_number}: invalid line")
            # Continúa acumulando errores.
            continue
        # Extrae el hash esperado y la ruta relativa.
        expected_hash, relative_path = parts
        # Elimina un asterisco opcional de formatos sha256sum tradicionales.
        relative_path = relative_path.lstrip("*")
        # Valida la longitud y caracteres del hash.
        if SHA256_RE.fullmatch(expected_hash) is None:
            # Registra hash mal formado.
            errors.append(f"MANIFEST.sha256:{line_number}: invalid SHA-256")
            # Continúa sin añadir la entrada.
            continue
        # Impide rutas absolutas o traversal en el inventario.
        normalized = Path(relative_path)
        # Comprueba que la ruta se mantenga relativa y no contenga .. .
        if normalized.is_absolute() or ".." in normalized.parts:
            # Registra una ruta insegura.
            errors.append(f"MANIFEST.sha256:{line_number}: unsafe path {relative_path}")
            # Continúa sin añadirla.
            continue
        # Detecta duplicados que podrían ocultar una discrepancia.
        if relative_path in entries:
            # Registra la duplicación.
            errors.append(f"MANIFEST.sha256:{line_number}: duplicate path {relative_path}")
            # Continúa sin sobrescribir el valor anterior.
            continue
        # Guarda la entrada validada.
        entries[relative_path] = expected_hash
    # Devuelve inventario y errores.
    return entries, errors

# Valida sintaxis Python sin importar ni ejecutar el fichero analizado.
def validate_python_syntax(path: Path) -> list[str]:
    # Inicializa la colección de errores de sintaxis.
    errors: list[str] = []
    # Lee el código como UTF-8 para usar el mismo contenido que se distribuirá.
    source = path.read_text(encoding="utf-8")
    # Intenta compilar únicamente a un objeto de código en memoria.
    try:
        # Usa compile para detectar errores sintácticos sin crear __pycache__ ni ejecutar imports.
        compile(source, str(path), "exec")
    # Captura exclusivamente errores de sintaxis del código empaquetado.
    except SyntaxError as exc:
        # Registra ruta, línea y mensaje de forma accionable.
        errors.append(f"{path}: Python syntax error at line {exc.lineno}: {exc.msg}")
    # Devuelve los problemas detectados.
    return errors

# Valida que MANIFEST.sha256 cubra exactamente el bundle actual.
def validate_manifest(root: Path) -> list[str]:
    # Inicializa errores de integridad.
    errors: list[str] = []
    # Define la ruta del manifiesto.
    manifest_file = root / "MANIFEST.sha256"
    # Comprueba que exista el fichero de integridad.
    if not manifest_file.is_file():
        # Devuelve un error único y accionable.
        return ["missing MANIFEST.sha256"]
    # Parsea el contenido declarado.
    entries, parse_errors = parse_manifest(manifest_file)
    # Incorpora errores sintácticos encontrados.
    errors.extend(parse_errors)
    # Construye el conjunto real de ficheros excepto el propio manifiesto.
    actual_files = {
        # Normaliza separadores a / para que el manifiesto sea portable.
        path.relative_to(root).as_posix(): path
        # Recorre todo el árbol del bundle.
        for path in root.rglob("*")
        # Conserva únicamente ficheros regulares distintos del manifiesto.
        if path.is_file() and path.name != "MANIFEST.sha256"
    }
    # Detecta ficheros no inventariados.
    for relative_path in sorted(set(actual_files) - set(entries)):
        # Registra el fichero extra.
        errors.append(f"MANIFEST.sha256 missing file: {relative_path}")
    # Detecta entradas cuyo fichero ya no existe.
    for relative_path in sorted(set(entries) - set(actual_files)):
        # Registra la entrada obsoleta.
        errors.append(f"MANIFEST.sha256 references missing file: {relative_path}")
    # Verifica cada hash cuando el fichero existe en ambos conjuntos.
    for relative_path in sorted(set(entries) & set(actual_files)):
        # Calcula el hash real.
        actual_hash = sha256_file(actual_files[relative_path])
        # Compara contra el valor declarado.
        if actual_hash != entries[relative_path]:
            # Registra cualquier alteración o manifiesto desactualizado.
            errors.append(f"MANIFEST.sha256 hash mismatch: {relative_path}")
    # Devuelve todos los errores de integridad.
    return errors

# Ejecuta la validación completa del bundle.
def main() -> int:
    # Resuelve la raíz del paquete a partir de la ubicación estable de este script.
    root = Path(__file__).resolve().parents[3]
    # Inicializa la colección global de errores.
    errors: list[str] = []
    # Define la ruta del manifiesto del plugin.
    plugin_file = root / ".codex-plugin" / "plugin.json"
    # Comprueba que el manifiesto exista.
    if not plugin_file.is_file():
        # Registra la ausencia.
        errors.append("missing .codex-plugin/plugin.json")
    else:
        # Intenta parsear el JSON del plugin.
        try:
            # Carga el manifiesto en memoria.
            plugin = json.loads(plugin_file.read_text(encoding="utf-8"))
        # Captura sintaxis JSON inválida.
        except json.JSONDecodeError as exc:
            # Registra el error con su detalle.
            errors.append(f"plugin.json invalid JSON: {exc}")
            # Usa un objeto vacío para continuar otras comprobaciones.
            plugin = {}
        # Valida las claves mínimas documentadas del bundle.
        for required in ("name", "version", "description", "skills"):
            # Comprueba cada campo obligatorio.
            if not plugin.get(required):
                # Registra la ausencia concreta.
                errors.append(f"plugin.json missing {required}")
        # Obtiene el nombre del plugin.
        plugin_name = str(plugin.get("name", ""))
        # Valida su formato cuando existe.
        if plugin_name and KEBAB_RE.fullmatch(plugin_name) is None:
            # Registra formato inesperado.
            errors.append(f"plugin.json name is not kebab-case: {plugin_name}")
        # Obtiene la ruta declarada de skills.
        skills_entry = str(plugin.get("skills", ""))
        # Resuelve la ruta declarada solo cuando existe.
        if skills_entry:
            # Normaliza contra la raíz del plugin.
            declared_skills = (root / skills_entry).resolve()
            # Comprueba que se mantenga dentro del paquete y sea directorio.
            if root.resolve() not in declared_skills.parents and declared_skills != root.resolve():
                # Registra un escape del plugin root.
                errors.append("plugin.json skills path escapes plugin root")
            # Comprueba que el directorio declarado exista.
            if not declared_skills.is_dir():
                # Registra una ruta rota.
                errors.append(f"plugin.json skills path missing: {skills_entry}")
    # Define la ruta del lockfile externo.
    external_lock_file = root / "EXTERNAL-SKILLS.lock.json"
    # Comprueba que exista la fuente de verdad supply-chain.
    if not external_lock_file.is_file():
        # Registra la ausencia.
        errors.append("missing EXTERNAL-SKILLS.lock.json")
    else:
        # Intenta cargar el lockfile.
        try:
            # Parsea la configuración JSON.
            external_lock = json.loads(external_lock_file.read_text(encoding="utf-8"))
        # Captura sintaxis inválida.
        except json.JSONDecodeError as exc:
            # Registra el fallo.
            errors.append(f"EXTERNAL-SKILLS.lock.json invalid JSON: {exc}")
            # Continúa con un objeto vacío.
            external_lock = {}
        # Obtiene el commit fijado.
        pinned_commit = str(external_lock.get("pinned_commit", ""))
        # Exige un SHA completo.
        if GIT_SHA_RE.fullmatch(pinned_commit) is None:
            # Registra pin ambiguo o inválido.
            errors.append("EXTERNAL-SKILLS.lock.json has invalid pinned_commit")
        # Obtiene el repositorio de origen.
        source_repository = str(external_lock.get("source_repository", ""))
        # Exige HTTPS GitHub para este bundle concreto.
        if not source_repository.startswith("https://github.com/"):
            # Registra una fuente inesperada.
            errors.append("EXTERNAL-SKILLS.lock.json has unexpected source_repository")
        # Obtiene el mapa de perfiles.
        profiles = external_lock.get("profiles")
        # Comprueba su tipo.
        if not isinstance(profiles, dict):
            # Registra estructura inválida.
            errors.append("EXTERNAL-SKILLS.lock.json missing profiles object")
        else:
            # Define los perfiles que el instalador espera poder resolver.
            required_profiles = {"web", "api_addon", "devsecops_addon"}
            # Comprueba que no falte ninguno.
            for missing_profile in sorted(required_profiles - set(profiles)):
                # Registra el perfil ausente.
                errors.append(f"EXTERNAL-SKILLS.lock.json missing profile: {missing_profile}")
            # Recorre cada perfil declarado.
            for profile_name, profile_skills in profiles.items():
                # Comprueba que sea una lista no vacía.
                if not isinstance(profile_skills, list) or not profile_skills:
                    # Registra el perfil mal formado.
                    errors.append(f"external profile is empty or invalid: {profile_name}")
                    # Continúa para acumular más problemas.
                    continue
                # Convierte elementos a texto.
                normalized_skills = [str(item) for item in profile_skills]
                # Detecta duplicados internos.
                if len(normalized_skills) != len(set(normalized_skills)):
                    # Registra el perfil afectado.
                    errors.append(f"external profile contains duplicates: {profile_name}")
                # Recorre cada nombre permitido.
                for external_skill_name in normalized_skills:
                    # Exige kebab-case para impedir rutas arbitrarias.
                    if KEBAB_RE.fullmatch(external_skill_name) is None:
                        # Registra el nombre inseguro o inesperado.
                        errors.append(f"invalid external skill name in {profile_name}: {external_skill_name}")
    # Localiza todos los SKILL.md propios empaquetados.
    skill_files = sorted((root / "skills").glob("*/SKILL.md"))
    # Comprueba que exista al menos una skill.
    if not skill_files:
        # Registra que el plugin estaría vacío.
        errors.append("no skills found")
    # Inicializa nombres vistos para detectar duplicados.
    names: set[str] = set()
    # Recorre cada skill propia.
    for skill_file in skill_files:
        # Valida estructura y frontmatter.
        name, skill_errors = validate_skill(skill_file)
        # Agrega sus errores.
        errors.extend(skill_errors)
        # Continúa validación de identidad únicamente con nombre.
        if name:
            # Detecta nombres duplicados.
            if name in names:
                # Registra el duplicado.
                errors.append(f"duplicate skill name: {name}")
            # Registra el nombre como visto.
            names.add(name)
            # Comprueba coherencia carpeta/name.
            if skill_file.parent.name != name:
                # Registra incoherencia.
                errors.append(f"folder/name mismatch: {skill_file.parent.name} != {name}")
        # Define la metadata opcional de UI/activación.
        openai_yaml = skill_file.parent / "agents" / "openai.yaml"
        # Comprueba que las skills propias incluyan el fichero esperado por este bundle.
        if not openai_yaml.is_file():
            # Registra ausencia de metadata.
            errors.append(f"missing agents/openai.yaml for {skill_file.parent.name}")
    # Define la copia de soporte de usuario-torpe-qa que permite una instalación dinámica autosuficiente.
    support_skill_file = root / "support-skills" / "usuario-torpe-qa" / "SKILL.md"
    # Comprueba que exista la skill de soporte.
    if not support_skill_file.is_file():
        # Registra que la integración dinámica quedaría incompleta.
        errors.append("missing bundled support skill: usuario-torpe-qa")
    else:
        # Valida su frontmatter con las mismas reglas básicas que una skill propia.
        support_name, support_errors = validate_skill(support_skill_file)
        # Agrega cualquier problema estructural.
        errors.extend(support_errors)
        # Exige el nombre exacto para que el orquestador pueda descubrirla.
        if support_name != "usuario-torpe-qa":
            # Registra una identidad inesperada.
            errors.append(f"bundled support skill name mismatch: {support_name}")
        # Define los auxiliares referenciados directamente por el SKILL.md original.
        support_required_files = (
            # Exige perfiles humanos.
            "references/perfiles.md",
            # Exige catálogo de mal uso.
            "references/catalogo-pruebas.md",
            # Exige referencia WordPress.
            "references/wordpress.md",
            # Exige plantilla de informe.
            "templates/informe.md",
            # Exige tabla de incidencias.
            "templates/tabla-incidencias.md",
            # Exige metadata de discovery.
            "agents/openai.yaml",
            # Exige marcador que permite desinstalar solo copias realmente instaladas por el bundle.
            ".sabas-bundled-support.json",
        )
        # Recorre todos los auxiliares de soporte.
        for support_relative_path in support_required_files:
            # Comprueba que el fichero exista dentro de la skill de soporte.
            if not (support_skill_file.parent / support_relative_path).is_file():
                # Registra la ruta exacta que falta.
                errors.append(f"missing usuario-torpe-qa support file: {support_relative_path}")
        # Define el marcador que autoriza una desinstalación segura de la copia completa creada por el bundle.
        support_marker_file = support_skill_file.parent / ".sabas-bundled-support.json"
        # Intenta validar su estructura únicamente cuando existe.
        if support_marker_file.is_file():
            # Carga el marcador de procedencia como JSON.
            try:
                # Parsea el contenido sin ejecutar ninguna lógica externa.
                support_marker = json.loads(support_marker_file.read_text(encoding="utf-8"))
            # Captura un JSON corrupto.
            except json.JSONDecodeError as exc:
                # Registra el fallo porque impediría demostrar la procedencia al desinstalar.
                errors.append(f"usuario-torpe-qa support marker invalid JSON: {exc}")
                # Continúa con un objeto vacío para acumular más errores.
                support_marker = {}
            # Comprueba que el marcador pertenezca a este bundle.
            if support_marker.get("bundle") != "sabas-secure-development":
                # Registra una procedencia inesperada.
                errors.append("usuario-torpe-qa support marker has unexpected bundle")
            # Comprueba que identifique la skill exacta.
            if support_marker.get("support_skill") != "usuario-torpe-qa":
                # Registra una identidad inconsistente.
                errors.append("usuario-torpe-qa support marker has unexpected skill")
    # Define el hook de seguridad de Codex incluido.
    hook_script = root / "scripts" / "SabasSecureStopHook.py"
    # Define el plugin nativo de seguridad de Hermes incluido.
    hermes_plugin_script = root / "hermes-plugin" / "sabas-secure-development" / "__init__.py"
    # Define el manifiesto del plugin Hermes.
    hermes_plugin_manifest = root / "hermes-plugin" / "sabas-secure-development" / "plugin.yaml"
    # Exige el código del plugin Hermes porque V0.5.4 ofrece instalación nativa en ese agente.
    if not hermes_plugin_script.is_file():
        # Registra ausencia del guardrail Hermes.
        errors.append("missing Hermes plugin __init__.py")
    # Exige el manifiesto del plugin Hermes.
    if not hermes_plugin_manifest.is_file():
        # Registra ausencia del manifiesto.
        errors.append("missing Hermes plugin plugin.yaml")
    # Exige su presencia porque la documentación lo ofrece como guardrail instalable.
    if not hook_script.is_file():
        # Registra ausencia del script.
        errors.append("missing scripts/SabasSecureStopHook.py")
    # Define la plantilla JSON de hooks.
    hook_template = root / "templates" / "hooks.sabas-secure.json"
    # Comprueba que exista.
    if not hook_template.is_file():
        # Registra ausencia de plantilla.
        errors.append("missing templates/hooks.sabas-secure.json")
    else:
        # Intenta parsear su JSON.
        try:
            # Carga la plantilla.
            hook_config = json.loads(hook_template.read_text(encoding="utf-8"))
        # Captura sintaxis inválida.
        except json.JSONDecodeError as exc:
            # Registra fallo concreto.
            errors.append(f"hooks.sabas-secure.json invalid JSON: {exc}")
            # Continúa con objeto vacío.
            hook_config = {}
        # Obtiene la lista Stop de manera defensiva.
        stop_hooks = hook_config.get("hooks", {}).get("Stop", []) if isinstance(hook_config.get("hooks"), dict) else []
        # Exige al menos un handler Stop.
        if not stop_hooks:
            # Registra plantilla sin guardrail real.
            errors.append("hooks.sabas-secure.json missing Stop hook")
    # Define los scripts Python que deben ser sintácticamente válidos antes de distribuirse.
    python_scripts = (
        # Incluye el clasificador determinista.
        root / "skills" / "sabas-secure-qa" / "scripts" / "security_context.py",
        # Incluye el validador que está ejecutando esta comprobación.
        root / "skills" / "sabas-secure-qa" / "scripts" / "validate_bundle.py",
        # Incluye el hook Stop opcional de Codex.
        hook_script,
        # Incluye el plugin nativo de Hermes.
        hermes_plugin_script,
        # Incluye la batería de regresión distribuida.
        root / "tests" / "test_sabas_secure_dev.py",
    )
    # Recorre cada script sin crear bytecode en disco.
    for python_script in python_scripts:
        # Comprueba que exista antes de leerlo.
        if python_script.is_file():
            # Agrega cualquier error de sintaxis detectado por compile.
            errors.extend(validate_python_syntax(python_script))
        else:
            # Registra ausencia con una ruta relativa clara.
            errors.append(f"missing Python script: {python_script.relative_to(root)}")
    # Comprueba referencias críticas nuevas del orquestador.
    for relative_reference in (
        # Exige el routing de la capa oficial.
        "skills/sabas-secure-qa/references/codex-security-integration.md",
        # Exige la integración de usuario torpe.
        "skills/sabas-secure-qa/references/usuario-torpe-integration.md",
        # Exige las reglas de bloqueo.
        "skills/sabas-secure-qa/references/security-gates.md",
        # Exige la referencia de integración nativa con Hermes añadida en V0.5.4.
        "skills/sabas-secure-qa/references/hermes-security-integration.md",
    ):
        # Comprueba cada fichero.
        if not (root / relative_reference).is_file():
            # Registra la referencia rota.
            errors.append(f"missing required reference: {relative_reference}")
    # Valida la integridad exacta del bundle mediante MANIFEST.sha256.
    errors.extend(validate_manifest(root))
    # Emite errores y falla cuando exista cualquier problema.
    if errors:
        # Recorre errores en el orden detectado.
        for error in errors:
            # Imprime cada uno con prefijo inequívoco.
            print(f"ERROR: {error}")
        # Devuelve código no cero.
        return 1
    # Construye el inventario real para el resumen.
    package_files = sorted(path for path in root.rglob("*") if path.is_file() and path.name != "MANIFEST.sha256")
    # Imprime resumen de éxito.
    print(f"OK: bundle valid; skills={len(skill_files)} files={len(package_files)} manifest=verified")
    # Imprime hashes de las skills principales para auditoría rápida.
    for skill_file in skill_files:
        # Emite ruta relativa y hash calculado.
        print(f"SHA256 {skill_file.relative_to(root)} {sha256_file(skill_file)}")
    # Devuelve éxito.
    return 0

# Ejecuta el validador únicamente como programa principal.
if __name__ == "__main__":
    # Propaga el código de salida al shell.
    raise SystemExit(main())
