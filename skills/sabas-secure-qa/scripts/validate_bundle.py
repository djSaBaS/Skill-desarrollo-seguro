# Importa anotaciones diferidas para mantener compatibilidad de tipos.
from __future__ import annotations

# Importa hashlib para calcular y validar hashes SHA-256.
import hashlib
# Importa json para validar manifiestos y marcadores.
import json
# Importa re para validar frontmatter, nombres y hashes.
import re
# Importa sys para devolver un código de salida adecuado.
import sys
# Importa Path para operar con rutas de forma portable.
from pathlib import Path

# Define una expresión conservadora para localizar frontmatter YAML inicial.
FRONTMATTER_RE = re.compile(r"\A---\s*\n(?P<body>.*?)\n---\s*\n", re.DOTALL)
# Define las claves simples obligatorias que se extraen del frontmatter.
KEY_RE = re.compile(r"^(?P<key>name|description):\s*(?P<value>.+?)\s*$", re.MULTILINE)
# Define nombres compatibles en kebab-case.
KEBAB_RE = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*")
# Define el formato exacto de SHA-256.
SHA256_RE = re.compile(r"[0-9a-f]{64}")
# Define el formato exacto de un commit Git SHA-1 completo.
GIT_SHA_RE = re.compile(r"[0-9a-f]{40}")


# Calcula SHA-256 de un fichero sin cargarlo completo en memoria.
def sha256_file(path: Path) -> str:
    # Crea el acumulador SHA-256.
    digest = hashlib.sha256()
    # Abre el fichero en binario para no alterar saltos de línea ni codificación.
    with path.open("rb") as handle:
        # Lee por bloques hasta EOF.
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            # Incorpora el bloque al digest.
            digest.update(chunk)
    # Devuelve el hexadecimal en minúsculas.
    return digest.hexdigest()


# Devuelve los ficheros que forman parte del bundle distribuible.
def collect_bundle_files(root: Path) -> dict[str, Path]:
    # Inicializa el inventario real.
    files: dict[str, Path] = {}
    # Recorre todo el árbol, incluidos dotfiles.
    for path in root.rglob("*"):
        # Omite directorios.
        if not path.is_file():
            # Continúa con la siguiente entrada.
            continue
        # Calcula la ruta relativa de forma portable.
        relative = path.relative_to(root)
        # Excluye metadatos internos de Git porque no forman parte del artefacto distribuible.
        if relative.parts and relative.parts[0] == ".git":
            # Continúa sin inventariar .git.
            continue
        # Excluye el propio manifiesto para evitar autorreferencia.
        if relative.as_posix() == "MANIFEST.sha256":
            # Continúa con el siguiente fichero.
            continue
        # Registra el fichero distribuible.
        files[relative.as_posix()] = path
    # Devuelve el inventario completo.
    return files


# Valida un SKILL.md y devuelve nombre y errores.
def validate_skill(skill_file: Path) -> tuple[str | None, list[str]]:
    # Inicializa errores.
    errors: list[str] = []
    # Lee la skill como UTF-8.
    text = skill_file.read_text(encoding="utf-8")
    # Localiza el frontmatter.
    match = FRONTMATTER_RE.search(text)
    # Exige frontmatter inicial.
    if match is None:
        # Registra el fallo.
        errors.append(f"{skill_file}: missing YAML frontmatter")
        # No hay identidad fiable.
        return None, errors
    # Extrae name y description.
    values = {
        item.group("key"): item.group("value").strip().strip("\"'")
        for item in KEY_RE.finditer(match.group("body"))
    }
    # Obtiene el nombre.
    name = values.get("name")
    # Exige nombre.
    if not name:
        # Registra la ausencia.
        errors.append(f"{skill_file}: missing name")
    # Exige descripción.
    if not values.get("description"):
        # Registra la ausencia.
        errors.append(f"{skill_file}: missing description")
    # Valida kebab-case.
    if name and KEBAB_RE.fullmatch(name) is None:
        # Registra formato inválido.
        errors.append(f"{skill_file}: name is not kebab-case: {name}")
    # Devuelve resultado.
    return name, errors


# Lee un JSON y exige que su raíz sea un objeto.
def read_json_object(path: Path, label: str, errors: list[str]) -> dict:
    # Devuelve vacío si el fichero no existe.
    if not path.is_file():
        # Registra la ausencia.
        errors.append(f"missing {label}")
        # Continúa con objeto vacío.
        return {}
    # Intenta interpretar JSON.
    try:
        # Carga el contenido UTF-8.
        value = json.loads(path.read_text(encoding="utf-8"))
    # Captura sintaxis JSON inválida.
    except json.JSONDecodeError as exc:
        # Registra el diagnóstico.
        errors.append(f"{label} invalid JSON: {exc}")
        # Continúa con objeto vacío.
        return {}
    # Exige objeto raíz.
    if not isinstance(value, dict):
        # Registra tipo inesperado.
        errors.append(f"{label} root is not an object")
        # Continúa con objeto vacío.
        return {}
    # Devuelve el objeto validado.
    return value


# Parsea MANIFEST.sha256 de forma segura.
def parse_manifest(manifest_file: Path) -> tuple[dict[str, str], list[str]]:
    # Inicializa entradas y errores.
    entries: dict[str, str] = {}
    # Inicializa errores sintácticos.
    errors: list[str] = []
    # Recorre líneas con número.
    for line_number, raw_line in enumerate(
        manifest_file.read_text(encoding="utf-8").splitlines(), start=1
    ):
        # Limpia espacios exteriores.
        line = raw_line.strip()
        # Ignora líneas vacías.
        if not line:
            # Continúa.
            continue
        # Divide hash y ruta una sola vez.
        parts = line.split(maxsplit=1)
        # Exige ambos componentes.
        if len(parts) != 2:
            # Registra sintaxis inválida.
            errors.append(f"MANIFEST.sha256:{line_number}: invalid line")
            # Continúa.
            continue
        # Extrae componentes.
        expected_hash, relative_path = parts
        # Tolera asterisco de sha256sum.
        relative_path = relative_path.lstrip("*")
        # Valida el hash.
        if SHA256_RE.fullmatch(expected_hash) is None:
            # Registra hash inválido.
            errors.append(f"MANIFEST.sha256:{line_number}: invalid SHA-256")
            # Continúa.
            continue
        # Normaliza la ruta.
        normalized = Path(relative_path)
        # Impide rutas absolutas y traversal.
        if normalized.is_absolute() or ".." in normalized.parts:
            # Registra ruta insegura.
            errors.append(f"MANIFEST.sha256:{line_number}: unsafe path {relative_path}")
            # Continúa.
            continue
        # Impide incluir .git dentro del manifiesto distribuible.
        if normalized.parts and normalized.parts[0] == ".git":
            # Registra metadatos internos no distribuibles.
            errors.append(f"MANIFEST.sha256:{line_number}: .git metadata is not distributable")
            # Continúa.
            continue
        # Detecta duplicados.
        if relative_path in entries:
            # Registra duplicado.
            errors.append(f"MANIFEST.sha256:{line_number}: duplicate path {relative_path}")
            # Continúa.
            continue
        # Guarda la entrada.
        entries[relative_path] = expected_hash
    # Devuelve entradas y errores.
    return entries, errors


# Valida que el manifiesto cubra exactamente el bundle distribuible.
def validate_manifest(root: Path) -> list[str]:
    # Inicializa errores.
    errors: list[str] = []
    # Resuelve el manifiesto.
    manifest_file = root / "MANIFEST.sha256"
    # Exige el manifiesto.
    if not manifest_file.is_file():
        # Devuelve un único error accionable.
        return ["missing MANIFEST.sha256"]
    # Parsea el inventario declarado.
    entries, parse_errors = parse_manifest(manifest_file)
    # Acumula errores de parseo.
    errors.extend(parse_errors)
    # Obtiene el inventario real excluyendo .git.
    actual_files = collect_bundle_files(root)
    # Detecta ficheros no inventariados.
    for relative_path in sorted(set(actual_files) - set(entries)):
        # Registra el fichero extra.
        errors.append(f"MANIFEST.sha256 missing file: {relative_path}")
    # Detecta entradas obsoletas.
    for relative_path in sorted(set(entries) - set(actual_files)):
        # Registra la entrada sin fichero.
        errors.append(f"MANIFEST.sha256 references missing file: {relative_path}")
    # Compara hashes comunes.
    for relative_path in sorted(set(entries) & set(actual_files)):
        # Calcula hash real.
        actual_hash = sha256_file(actual_files[relative_path])
        # Registra discrepancias.
        if actual_hash != entries[relative_path]:
            # Informa del fichero afectado.
            errors.append(f"MANIFEST.sha256 hash mismatch: {relative_path}")
    # Devuelve todos los errores.
    return errors


# Valida sintaxis Python sin importar ni ejecutar el fichero.
def validate_python_syntax(path: Path) -> list[str]:
    # Inicializa errores.
    errors: list[str] = []
    # Lee el código.
    source = path.read_text(encoding="utf-8")
    # Intenta compilar en memoria.
    try:
        # Compila sin ejecutar imports.
        compile(source, str(path), "exec")
    # Captura únicamente errores sintácticos.
    except SyntaxError as exc:
        # Registra línea y mensaje.
        errors.append(f"{path}: Python syntax error at line {exc.lineno}: {exc.msg}")
    # Devuelve errores.
    return errors


# Ejecuta la validación completa del bundle.
def main() -> int:
    # Resuelve la raíz estable del bundle.
    root = Path(__file__).resolve().parents[3]
    # Inicializa errores globales.
    errors: list[str] = []

    # Valida el manifiesto del plugin Codex.
    plugin = read_json_object(root / ".codex-plugin" / "plugin.json", ".codex-plugin/plugin.json", errors)
    # Exige las claves mínimas.
    for required in ("name", "version", "description", "skills"):
        # Comprueba cada clave.
        if not plugin.get(required):
            # Registra la ausencia.
            errors.append(f"plugin.json missing {required}")
    # Valida el nombre del plugin.
    plugin_name = str(plugin.get("name", ""))
    # Exige kebab-case cuando existe.
    if plugin_name and KEBAB_RE.fullmatch(plugin_name) is None:
        # Registra formato inesperado.
        errors.append(f"plugin.json name is not kebab-case: {plugin_name}")
    # Valida la ruta declarada de skills.
    skills_entry = str(plugin.get("skills", ""))
    # Procesa solo cuando existe.
    if skills_entry:
        # Resuelve la ruta.
        declared_skills = (root / skills_entry).resolve()
        # Impide escapar de la raíz.
        if root.resolve() not in declared_skills.parents and declared_skills != root.resolve():
            # Registra escape.
            errors.append("plugin.json skills path escapes plugin root")
        # Exige directorio existente.
        if not declared_skills.is_dir():
            # Registra ruta rota.
            errors.append(f"plugin.json skills path missing: {skills_entry}")

    # Valida el lockfile de skills externas.
    external_lock = read_json_object(root / "EXTERNAL-SKILLS.lock.json", "EXTERNAL-SKILLS.lock.json", errors)
    # Obtiene commit fijado.
    pinned_commit = str(external_lock.get("pinned_commit", ""))
    # Exige SHA Git completo.
    if GIT_SHA_RE.fullmatch(pinned_commit) is None:
        # Registra pin inválido.
        errors.append("EXTERNAL-SKILLS.lock.json has invalid pinned_commit")
    # Obtiene origen.
    source_repository = str(external_lock.get("source_repository", ""))
    # Exige GitHub HTTPS.
    if not source_repository.startswith("https://github.com/"):
        # Registra origen inesperado.
        errors.append("EXTERNAL-SKILLS.lock.json has unexpected source_repository")
    # Obtiene perfiles.
    profiles = external_lock.get("profiles")
    # Exige objeto de perfiles.
    if not isinstance(profiles, dict):
        # Registra estructura inválida.
        errors.append("EXTERNAL-SKILLS.lock.json missing profiles object")
    else:
        # Define perfiles requeridos.
        required_profiles = {"web", "api_addon", "devsecops_addon"}
        # Registra perfiles ausentes.
        for missing_profile in sorted(required_profiles - set(profiles)):
            # Informa el nombre.
            errors.append(f"EXTERNAL-SKILLS.lock.json missing profile: {missing_profile}")
        # Recorre perfiles.
        for profile_name, profile_skills in profiles.items():
            # Exige lista no vacía.
            if not isinstance(profile_skills, list) or not profile_skills:
                # Registra perfil inválido.
                errors.append(f"external profile is empty or invalid: {profile_name}")
                # Continúa.
                continue
            # Normaliza nombres.
            normalized_skills = [str(item) for item in profile_skills]
            # Detecta duplicados.
            if len(normalized_skills) != len(set(normalized_skills)):
                # Registra duplicación.
                errors.append(f"external profile contains duplicates: {profile_name}")
            # Valida cada nombre.
            for external_skill_name in normalized_skills:
                # Exige kebab-case.
                if KEBAB_RE.fullmatch(external_skill_name) is None:
                    # Registra nombre inválido.
                    errors.append(f"invalid external skill name in {profile_name}: {external_skill_name}")

    # Localiza todas las skills propias.
    skill_files = sorted((root / "skills").glob("*/SKILL.md"))
    # Exige al menos una skill.
    if not skill_files:
        # Registra bundle vacío.
        errors.append("no skills found")
    # Inicializa nombres vistos.
    names: set[str] = set()
    # Recorre skills.
    for skill_file in skill_files:
        # Valida frontmatter.
        name, skill_errors = validate_skill(skill_file)
        # Acumula errores.
        errors.extend(skill_errors)
        # Comprueba identidad.
        if name:
            # Detecta duplicados.
            if name in names:
                # Registra duplicado.
                errors.append(f"duplicate skill name: {name}")
            # Conserva nombre.
            names.add(name)
            # Exige coherencia carpeta/nombre.
            if skill_file.parent.name != name:
                # Registra incoherencia.
                errors.append(f"folder/name mismatch: {skill_file.parent.name} != {name}")
        # Exige metadata OpenAI para cada skill propia.
        if not (skill_file.parent / "agents" / "openai.yaml").is_file():
            # Registra metadata ausente.
            errors.append(f"missing agents/openai.yaml for {skill_file.parent.name}")

    # Valida la skill de soporte usuario-torpe-qa.
    support_root = root / "support-skills" / "usuario-torpe-qa"
    # Define su SKILL.md.
    support_skill_file = support_root / "SKILL.md"
    # Exige la skill.
    if not support_skill_file.is_file():
        # Registra ausencia.
        errors.append("missing bundled support skill: usuario-torpe-qa")
    else:
        # Valida frontmatter.
        support_name, support_errors = validate_skill(support_skill_file)
        # Acumula errores.
        errors.extend(support_errors)
        # Exige identidad exacta.
        if support_name != "usuario-torpe-qa":
            # Registra identidad inesperada.
            errors.append(f"bundled support skill name mismatch: {support_name}")
        # Define auxiliares requeridos.
        support_required_files = (
            "references/perfiles.md",
            "references/catalogo-pruebas.md",
            "references/wordpress.md",
            "templates/informe.md",
            "templates/tabla-incidencias.md",
            "agents/openai.yaml",
            ".sabas-bundled-support.json",
        )
        # Exige cada auxiliar.
        for relative_path in support_required_files:
            # Comprueba el fichero.
            if not (support_root / relative_path).is_file():
                # Registra la ruta.
                errors.append(f"missing usuario-torpe-qa support file: {relative_path}")
        # Valida el marcador de propiedad.
        support_marker = read_json_object(
            support_root / ".sabas-bundled-support.json",
            "usuario-torpe-qa support marker",
            errors,
        )
        # Exige bundle exacto.
        if support_marker and support_marker.get("bundle") != "sabas-secure-development":
            # Registra procedencia inesperada.
            errors.append("usuario-torpe-qa support marker has unexpected bundle")
        # Exige skill exacta.
        if support_marker and support_marker.get("support_skill") != "usuario-torpe-qa":
            # Registra identidad inesperada.
            errors.append("usuario-torpe-qa support marker has unexpected skill")

    # Valida el hook de Codex.
    hook_script = root / "scripts" / "SabasSecureStopHook.py"
    # Exige el hook.
    if not hook_script.is_file():
        # Registra ausencia.
        errors.append("missing scripts/SabasSecureStopHook.py")

    # Valida el plugin Hermes y su marcador de propiedad.
    hermes_root = root / "hermes-plugin" / "sabas-secure-development"
    # Define el código del plugin.
    hermes_plugin_script = hermes_root / "__init__.py"
    # Define el manifiesto del plugin.
    hermes_plugin_manifest = hermes_root / "plugin.yaml"
    # Exige código.
    if not hermes_plugin_script.is_file():
        # Registra ausencia.
        errors.append("missing Hermes plugin __init__.py")
    # Exige manifiesto.
    if not hermes_plugin_manifest.is_file():
        # Registra ausencia.
        errors.append("missing Hermes plugin plugin.yaml")
    # Valida marcador de propiedad.
    hermes_marker = read_json_object(
        hermes_root / ".sabas-managed-plugin.json",
        "Hermes managed plugin marker",
        errors,
    )
    # Exige valores exactos cuando existe.
    if hermes_marker:
        # Comprueba gestor.
        if hermes_marker.get("managed_by") != "sabas-secure-development":
            # Registra gestor inesperado.
            errors.append("Hermes managed plugin marker has unexpected managed_by")
        # Comprueba componente.
        if hermes_marker.get("component") != "hermes-plugin":
            # Registra componente inesperado.
            errors.append("Hermes managed plugin marker has unexpected component")
        # Comprueba nombre.
        if hermes_marker.get("plugin_name") != "sabas-secure-development":
            # Registra nombre inesperado.
            errors.append("Hermes managed plugin marker has unexpected plugin_name")

    # Valida la plantilla de hooks.
    hook_template = root / "templates" / "hooks.sabas-secure.json"
    # Lee el JSON.
    hook_config = read_json_object(hook_template, "templates/hooks.sabas-secure.json", errors)
    # Obtiene hooks.
    hooks_section = hook_config.get("hooks") if isinstance(hook_config, dict) else None
    # Obtiene Stop defensivamente.
    stop_hooks = hooks_section.get("Stop", []) if isinstance(hooks_section, dict) else []
    # Exige al menos un Stop hook.
    if not stop_hooks:
        # Registra plantilla incompleta.
        errors.append("hooks.sabas-secure.json missing Stop hook")

    # Exige referencias críticas.
    required_references = (
        "skills/sabas-secure-qa/references/codex-security-integration.md",
        "skills/sabas-secure-qa/references/usuario-torpe-integration.md",
        "skills/sabas-secure-qa/references/security-gates.md",
        "skills/sabas-secure-qa/references/hermes-security-integration.md",
    )
    # Recorre referencias.
    for relative_reference in required_references:
        # Comprueba cada fichero.
        if not (root / relative_reference).is_file():
            # Registra la ausencia.
            errors.append(f"missing required reference: {relative_reference}")

    # Valida sintaxis Python de componentes distribuidos.
    python_scripts = (
        root / "skills" / "sabas-secure-qa" / "scripts" / "security_context.py",
        root / "skills" / "sabas-secure-qa" / "scripts" / "validate_bundle.py",
        hook_script,
        hermes_plugin_script,
        root / "tests" / "test_sabas_secure_dev.py",
        root / "tests" / "test_portable_setup.py",
    )
    # Recorre scripts.
    for python_script in python_scripts:
        # Valida cuando existe.
        if python_script.is_file():
            # Acumula errores sintácticos.
            errors.extend(validate_python_syntax(python_script))
        else:
            # Registra ausencia.
            errors.append(f"missing Python script: {python_script.relative_to(root)}")

    # Valida integridad exacta del artefacto distribuible.
    errors.extend(validate_manifest(root))

    # Falla cuando existe cualquier error.
    if errors:
        # Emite cada error de forma independiente.
        for error in errors:
            # Imprime diagnóstico.
            print(f"ERROR: {error}")
        # Devuelve código de fallo.
        return 1

    # Construye inventario final excluyendo .git.
    package_files = collect_bundle_files(root)
    # Emite resumen reproducible.
    print(f"OK: bundle valid; skills={len(skill_files)} files={len(package_files)} manifest=verified")
    # Emite hashes de las skills principales.
    for skill_file in skill_files:
        # Imprime ruta y SHA-256.
        print(f"SHA256 {skill_file.relative_to(root)} {sha256_file(skill_file)}")
    # Devuelve éxito.
    return 0


# Ejecuta el validador únicamente como programa principal.
if __name__ == "__main__":
    # Propaga el código de salida al shell.
    raise SystemExit(main())
