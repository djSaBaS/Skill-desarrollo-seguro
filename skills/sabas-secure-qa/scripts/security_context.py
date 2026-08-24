# Importa anotaciones diferidas para mantener tipos modernos sin acoplar la ejecución.
from __future__ import annotations

# Importa argparse para procesar los argumentos de línea de comandos de forma segura.
import argparse
# Importa hashlib para ligar el veredicto de seguridad al estado exacto del cambio.
import hashlib
# Importa json para emitir un resultado estructurado consumible por Codex.
import json
# Importa re para clasificar señales de riesgo sin ejecutar contenido del repositorio.
import re
# Importa shutil para detectar herramientas instaladas sin invocarlas.
import shutil
# Importa subprocess para consultar Git de forma controlada.
import subprocess
# Importa Path para manejar rutas sin concatenaciones frágiles.
from pathlib import Path
# Importa Any para tipar estructuras JSON heterogéneas.
from typing import Any

# Define extensiones que normalmente representan código ejecutable o configuración relevante.
CODE_SUFFIXES = {".php", ".py", ".js", ".jsx", ".ts", ".tsx", ".sql", ".sh", ".ps1", ".yml", ".yaml", ".json"}
# Define extensiones que normalmente representan documentación sin impacto ejecutable directo.
DOC_SUFFIXES = {".md", ".txt", ".rst", ".adoc"}
# Define directorios que no deben influir en el inventario de código propio.
IGNORED_PARTS = {".git", "vendor", "node_modules", "dist", "build", "coverage"}
# Define señales de alto riesgo que pueden aparecer en rutas o en líneas añadidas del diff.
HIGH_RISK_PATTERNS = {
    "authentication": re.compile(r"auth|login|logout|password|passwd|reset|mfa|session", re.IGNORECASE),
    "authorization": re.compile(r"permission|capabilit|authoriz|role|tenant|ownership|admin", re.IGNORECASE),
    "files": re.compile(r"upload|download|import|export|attachment|file", re.IGNORECASE),
    "external_effects": re.compile(r"webhook|payment|checkout|mail|email|sms|publish", re.IGNORECASE),
    "tokens": re.compile(r"jwt|oauth|oidc|saml|token", re.IGNORECASE),
    "ci_cd": re.compile(r"\.github/workflows|pipeline|deploy|release", re.IGNORECASE),
    # Detecta superficies API/AJAX/REST que suelen ampliar el límite de confianza.
    "api_surface": re.compile(r"\bapi\b|\bajax\b|\brest\b|graphql|endpoint", re.IGNORECASE),
}
# Define señales críticas que exigen una revisión profunda aunque el cambio sea pequeño.
CRITICAL_RISK_PATTERNS = {
    "code_execution": re.compile(r"\beval\s*\(|\bexec\s*\(|shell_exec|system\s*\(|passthru\s*\(|proc_open|subprocess", re.IGNORECASE),
    "unsafe_deserialization": re.compile(r"\bunserialize\s*\(|pickle\.loads|yaml\.load\s*\(", re.IGNORECASE),
    "secret_files": re.compile(r"(^|/)(\.env|wp-config\.php|.*private.*key.*|.*secret.*)(/|$)", re.IGNORECASE),
    "financial": re.compile(r"payment|checkout|balance|credit|invoice|refund|charge", re.IGNORECASE),
    "crypto": re.compile(r"encrypt|decrypt|cipher|private[_-]?key|signing[_-]?key|cryptograph", re.IGNORECASE),
}
# Define señales críticas que solo se evalúan sobre contenido añadido para evitar falsos positivos por nombres de archivo.
DIFF_CRITICAL_RISK_PATTERNS = {
    # Detecta asignaciones literales que parecen contener material de credencial sin conservar el valor detectado.
    "credential_literal": re.compile(r"(?:api[_-]?key|client[_-]?secret|access[_-]?token|password|passwd|private[_-]?key)\s*[=:]\s*[\'\"][^\'\"\n]{4,}", re.IGNORECASE),
}
# Define señales de alto riesgo que solo deben elevar el análisis cuando aparecen en código añadido.
DIFF_HIGH_RISK_PATTERNS = {
    # Detecta acceso SQL explícito para exigir revisión profunda de parametrización y autorización de datos.
    "data_access": re.compile(r"\$wpdb\b|\bmysqli\b|\bPDO\b|\bSELECT\b|\bINSERT\b|\bUPDATE\b|\bDELETE\b|\bprepare\s*\(", re.IGNORECASE),
    # Detecta sinks DOM habituales que requieren revisión contextual de XSS.
    "dom_sink": re.compile(r"innerHTML|outerHTML|insertAdjacentHTML|dangerouslySetInnerHTML", re.IGNORECASE),
}
# Define herramientas habituales cuya presencia mejora la cobertura del gate.
TOOLS = ["git", "php", "composer", "node", "npm", "python", "python3", "semgrep", "gitleaks", "trivy", "osv-scanner", "pip-audit", "docker"]

# Ejecuta un comando de solo lectura y devuelve su salida sin lanzar una excepción al llamador.
def run_readonly(command: list[str], cwd: Path) -> str:
    # Ejecuta el proceso sin shell para evitar expansión de comandos inesperada.
    process = subprocess.run(command, cwd=cwd, capture_output=True, text=True, check=False)
    # Devuelve una cadena vacía cuando el comando no finaliza correctamente.
    if process.returncode != 0:
        # Evita propagar mensajes de Git que pueden contener rutas innecesarias al resultado principal.
        return ""
    # Devuelve stdout sin espacios finales para simplificar el tratamiento posterior.
    return process.stdout.strip()

# Busca la raíz Git o usa la ruta indicada cuando no exista repositorio Git.
def resolve_repo_root(repo: Path) -> Path:
    # Resuelve la ruta para impedir ambigüedad por segmentos relativos.
    resolved = repo.resolve()
    # Consulta a Git sin modificar el repositorio.
    git_root = run_readonly(["git", "rev-parse", "--show-toplevel"], resolved)
    # Devuelve la raíz detectada cuando Git responde correctamente.
    if git_root:
        # Convierte la salida de Git en una ruta absoluta.
        return Path(git_root).resolve()
    # Usa la carpeta solicitada como fallback para repositorios sin Git.
    return resolved

# Obtiene la lista de archivos cambiados sin imprimir el contenido del diff.
def collect_changed_files(repo_root: Path) -> list[str]:
    # Consulta cambios del working tree respecto a HEAD.
    unstaged = run_readonly(["git", "diff", "--name-only", "HEAD"], repo_root)
    # Consulta cambios preparados para commit que podrían no aparecer en el comando anterior en ciertos estados.
    staged = run_readonly(["git", "diff", "--cached", "--name-only"], repo_root)
    # Consulta archivos nuevos no ignorados porque Codex suele crear ficheros antes de hacer git add.
    untracked = run_readonly(["git", "ls-files", "--others", "--exclude-standard"], repo_root)
    # Combina las tres fuentes preservando únicamente rutas no vacías.
    candidates = [line.strip() for block in (unstaged, staged, untracked) for line in block.splitlines() if line.strip()]
    # Elimina duplicados y ordena para que la salida sea determinista.
    return sorted(set(candidates))

# Obtiene exclusivamente contenido añadido para clasificar riesgo sin exponer valores completos al resultado.
def collect_added_diff(repo_root: Path) -> str:
    # Solicita un diff sin contexto para reducir contenido innecesario.
    diff = run_readonly(["git", "diff", "--unified=0", "HEAD"], repo_root)
    # Conserva solo líneas añadidas que no sean cabeceras de diff.
    added_lines = [line[1:] for line in diff.splitlines() if line.startswith("+") and not line.startswith("+++")]
    # Consulta archivos nuevos no ignorados que todavía no aparecen en git diff HEAD.
    untracked = run_readonly(["git", "ls-files", "--others", "--exclude-standard"], repo_root)
    # Recorre archivos nuevos con un límite estricto para incorporar señales de riesgo sin emitir su contenido.
    for relative_path in untracked.splitlines():
        # Normaliza la ruta relativa recibida desde Git.
        clean_path = relative_path.strip()
        # Omite rutas vacías o dependencias/build ignorados.
        if not clean_path or is_ignored(clean_path):
            # Continúa sin leer contenido irrelevante.
            continue
        # Construye la ruta local de forma segura a partir de la raíz ya resuelta.
        candidate = (repo_root / clean_path).resolve()
        # Impide leer rutas que escapen de la raíz por una resolución inesperada.
        if repo_root not in candidate.parents and candidate != repo_root:
            # Omite cualquier ruta fuera del repositorio.
            continue
        # Limita la lectura a archivos regulares de código/configuración de tamaño razonable.
        if not candidate.is_file() or candidate.suffix.lower() not in CODE_SUFFIXES or candidate.stat().st_size > 200_000:
            # Omite binarios, archivos enormes y formatos no necesarios para clasificación.
            continue
        # Lee texto sustituyendo bytes inválidos para evitar abortar el inventario por codificación.
        added_lines.append(candidate.read_text(encoding="utf-8", errors="replace")[:50_000])
    # Limita el texto analizado globalmente para evitar un consumo desproporcionado en cambios enormes.
    return "\n".join(added_lines)[:200_000]

# Detecta tecnologías mediante archivos de configuración y rutas características.
def detect_stack(repo_root: Path) -> list[str]:
    # Inicializa un conjunto para evitar tecnologías duplicadas.
    stack: set[str] = set()
    # Marca PHP/Composer cuando existe el manifiesto habitual.
    if (repo_root / "composer.json").exists():
        # Añade PHP/Composer como una sola etiqueta descriptiva.
        stack.add("php-composer")
    # Marca Node cuando existe package.json.
    if (repo_root / "package.json").exists():
        # Añade el ecosistema JavaScript/TypeScript.
        stack.add("node-js-ts")
    # Marca Python cuando existe cualquiera de sus manifiestos frecuentes.
    if any((repo_root / name).exists() for name in ("pyproject.toml", "requirements.txt", "Pipfile", "poetry.lock")):
        # Añade Python a la lista de stack.
        stack.add("python")
    # Marca contenedores cuando existe Dockerfile o Compose.
    if any((repo_root / name).exists() for name in ("Dockerfile", "docker-compose.yml", "docker-compose.yaml", "compose.yml", "compose.yaml")):
        # Añade Docker/containers.
        stack.add("docker")
    # Marca GitHub Actions cuando existe el directorio de workflows.
    if (repo_root / ".github" / "workflows").exists():
        # Añade CI de GitHub.
        stack.add("github-actions")
    # Busca señales de WordPress sin recorrer árboles gigantes.
    wordpress_markers = [repo_root / "wp-config.php", repo_root / "wp-content", repo_root / "wordpress"]
    # Comprueba los marcadores conocidos.
    if any(marker.exists() for marker in wordpress_markers):
        # Añade WordPress.
        stack.add("wordpress")
    # Si no hay marcadores, inspecciona composer.json de forma textual y limitada.
    composer_path = repo_root / "composer.json"
    # Comprueba primero que el fichero exista.
    if composer_path.exists():
        # Lee el manifiesto con errores de codificación sustituidos para no fallar el inventario.
        composer_text = composer_path.read_text(encoding="utf-8", errors="replace")[:200_000]
        # Detecta referencias típicas al ecosistema WordPress.
        if "wordpress" in composer_text.lower() or "wpackagist" in composer_text.lower():
            # Añade WordPress cuando el manifiesto lo confirma.
            stack.add("wordpress")
    # Devuelve una lista ordenada para resultados reproducibles.
    return sorted(stack)

# Determina si una ruta debe ignorarse por pertenecer a dependencias/build.
def is_ignored(path_text: str) -> bool:
    # Convierte la ruta a partes normalizadas.
    parts = Path(path_text).parts
    # Devuelve verdadero si alguna parte pertenece al conjunto ignorado.
    return any(part in IGNORED_PARTS for part in parts)

# Clasifica riesgo usando rutas y líneas añadidas sin emitir contenido sensible.
def classify_risk(changed_files: list[str], added_diff: str) -> dict[str, Any]:
    # Filtra dependencias y salidas generadas del análisis principal.
    relevant_files = [path for path in changed_files if not is_ignored(path)]
    # Inicializa razones de riesgo explicables.
    reasons: list[str] = []
    # Inicializa score en cero para cambios sin impacto ejecutable.
    score = 0
    # Determina si todos los cambios parecen documentales.
    docs_only = bool(relevant_files) and all(Path(path).suffix.lower() in DOC_SUFFIXES for path in relevant_files)
    # Devuelve R0 de forma temprana cuando todo es documentación.
    if docs_only:
        # Construye el resultado mínimo para documentación.
        return {"score": 0, "risk": "R0", "mode": "FAST", "reasons": ["documentation-only change"]}
    # Recorre las rutas para detectar superficies críticas.
    for path in relevant_files:
        # Evalúa cada patrón crítico contra la ruta.
        for label, pattern in CRITICAL_RISK_PATTERNS.items():
            # Incrementa riesgo cuando el patrón aparece.
            if pattern.search(path):
                # Eleva score a nivel R4.
                score = max(score, 4)
                # Registra una razón sin revelar contenido del archivo.
                reasons.append(f"critical surface in path: {label} ({path})")
        # Evalúa cada patrón alto contra la ruta.
        for label, pattern in HIGH_RISK_PATTERNS.items():
            # Detecta la señal relevante.
            if pattern.search(path):
                # Eleva como mínimo a R3.
                score = max(score, 3)
                # Registra la superficie.
                reasons.append(f"high-risk surface in path: {label} ({path})")
        # Eleva cambios en lockfiles/manifiestos a R2 por supply chain.
        if Path(path).name in {"composer.lock", "package-lock.json", "pnpm-lock.yaml", "yarn.lock", "poetry.lock", "Pipfile.lock", "requirements.txt", "pyproject.toml"}:
            # Marca riesgo moderado como mínimo.
            score = max(score, 2)
            # Registra supply chain.
            reasons.append(f"dependency/supply-chain file changed: {path}")
        # Eleva SQL/migraciones a R3 porque pueden afectar controles de datos.
        if Path(path).suffix.lower() == ".sql" or "migration" in path.lower():
            # Marca alto riesgo.
            score = max(score, 3)
            # Registra el motivo.
            reasons.append(f"database schema/query surface changed: {path}")
        # Marca código ordinario como R1 si no había señales superiores.
        if Path(path).suffix.lower() in CODE_SUFFIXES:
            # Garantiza al menos R1.
            score = max(score, 1)
    # Evalúa patrones críticos en líneas añadidas del diff sin incluir esas líneas en la salida.
    for label, pattern in CRITICAL_RISK_PATTERNS.items():
        # Comprueba el patrón sobre el texto añadido.
        if pattern.search(added_diff):
            # Eleva a R4.
            score = max(score, 4)
            # Registra únicamente el tipo de señal.
            reasons.append(f"critical pattern added in diff: {label}")
    # Evalúa patrones de alto riesgo en líneas añadidas.
    for label, pattern in HIGH_RISK_PATTERNS.items():
        # Comprueba la señal.
        if pattern.search(added_diff):
            # Eleva a R3 como mínimo.
            score = max(score, 3)
            # Registra el tipo de señal.
            reasons.append(f"high-risk pattern added in diff: {label}")
    # Evalúa señales críticas específicas de contenido añadido, como credenciales literales.
    for label, pattern in DIFF_CRITICAL_RISK_PATTERNS.items():
        # Comprueba el patrón sin añadir el valor coincidente a la salida.
        if pattern.search(added_diff):
            # Eleva a R4 para forzar un gate RELEASE.
            score = max(score, 4)
            # Registra únicamente la clase de señal detectada.
            reasons.append(f"critical content pattern added in diff: {label}")
    # Evalúa superficies de alto riesgo específicas del contenido añadido.
    for label, pattern in DIFF_HIGH_RISK_PATTERNS.items():
        # Comprueba la señal sin conservar el fragmento de código.
        if pattern.search(added_diff):
            # Eleva a R3 para exigir revisión profunda.
            score = max(score, 3)
            # Registra únicamente la categoría del riesgo.
            reasons.append(f"high-risk content pattern added in diff: {label}")
    # Si hay código pero no se detectó nada, usa R1.
    if relevant_files and score == 0:
        # Clasifica el cambio como bajo riesgo por defecto.
        score = 1
    # Mapea score numérico a etiqueta R0-R4.
    risk = f"R{score}"
    # Selecciona el modo recomendado según la política V0.5.4.
    mode = {0: "FAST", 1: "FAST", 2: "STANDARD", 3: "DEEP", 4: "RELEASE"}[score]
    # Elimina razones duplicadas conservando orden.
    unique_reasons = list(dict.fromkeys(reasons))
    # Devuelve el resultado estructurado.
    return {"score": score, "risk": risk, "mode": mode, "reasons": unique_reasons}

# Calcula una huella estable del estado actual del cambio sin incluir contenido sensible en la salida.
def calculate_gate_fingerprint(repo_root: Path, changed_files: list[str]) -> str:
    # Inicializa SHA-256 con una etiqueta de versión para permitir evolucionar el esquema de forma explícita.
    digest = hashlib.sha256(b"sabas-security-gate-fingerprint-v1\0")
    # Obtiene el commit base para que el mismo contenido sobre otra base produzca una huella distinta.
    head_commit = run_readonly(["git", "rev-parse", "HEAD"], repo_root)
    # Incorpora el commit base sin exponerlo como requisito de lógica posterior.
    digest.update(head_commit.encode("utf-8", errors="replace"))
    # Añade un separador inequívoco entre componentes.
    digest.update(b"\0")
    # Ejecuta git status en formato NUL para incorporar estado, renombres, cambios de modo y archivos no versionados.
    try:
        # Captura bytes directamente para no reinterpretar nombres de archivo especiales.
        status_process = subprocess.run(
            # Solicita un estado machine-readable de solo lectura.
            ["git", "status", "--porcelain=v1", "-z", "--untracked-files=all"],
            # Ejecuta desde la raíz resuelta del repositorio.
            cwd=repo_root,
            # Captura stdout y stderr sin usar shell.
            capture_output=True,
            # No lanza por código distinto de cero para permitir repositorios sin Git.
            check=False,
            # Limita el tiempo para que el fingerprint no bloquee el flujo.
            timeout=20,
        )
    # Captura timeout o fallo del sistema y continúa con la evidencia de rutas/contenido disponible.
    except (subprocess.TimeoutExpired, OSError):
        # Usa ausencia de estado Git como fallback explícito.
        status_process = None
    # Incorpora el estado únicamente cuando Git terminó correctamente.
    if status_process is not None and status_process.returncode == 0:
        # Añade los bytes sin mostrarlos en el JSON final.
        digest.update(status_process.stdout)
    # Añade un separador antes de procesar archivos actuales.
    digest.update(b"\0FILES\0")
    # Recorre rutas en orden para obtener un resultado determinista.
    for relative_path in sorted(changed_files):
        # Normaliza la ruta como objeto Path sin resolver enlaces simbólicos todavía.
        relative = Path(relative_path)
        # Rechaza rutas absolutas o traversal aunque provengan de Git.
        if relative.is_absolute() or ".." in relative.parts:
            # Incorpora una marca segura para que el estado anómalo siga afectando la huella.
            digest.update(f"UNSAFE:{relative_path}".encode("utf-8", errors="replace"))
            # Continúa sin acceder a esa ruta.
            continue
        # Incorpora el nombre de la ruta antes de su estado/contenido.
        digest.update(relative_path.encode("utf-8", errors="replace"))
        # Añade un separador para evitar concatenaciones ambiguas.
        digest.update(b"\0")
        # Construye la ruta local sin seguir enlaces simbólicos.
        candidate = repo_root / relative
        # Distingue enlaces simbólicos para no leer contenido fuera de la raíz.
        if candidate.is_symlink():
            # Incorpora únicamente el destino textual del enlace.
            digest.update(b"SYMLINK\0")
            # Añade el destino del enlace sin abrirlo.
            digest.update(str(candidate.readlink()).encode("utf-8", errors="replace"))
            # Continúa con la siguiente ruta.
            continue
        # Marca eliminaciones o rutas ya inexistentes.
        if not candidate.exists():
            # Incorpora un estado explícito de eliminación.
            digest.update(b"DELETED")
            # Continúa con la siguiente ruta.
            continue
        # Distingue directorios u otros tipos especiales sin intentar leerlos como fichero.
        if not candidate.is_file():
            # Incorpora una marca de tipo no regular.
            digest.update(b"NONREGULAR")
            # Continúa con la siguiente ruta.
            continue
        # Incorpora el tamaño para reforzar la separación de estados.
        digest.update(str(candidate.stat().st_size).encode("ascii"))
        # Añade separador antes de los bytes.
        digest.update(b"\0")
        # Abre el fichero actual en binario para cubrir cambios en cualquier formato.
        with candidate.open("rb") as handle:
            # Lee por bloques para no cargar ficheros grandes enteros en memoria.
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                # Incorpora cada bloque únicamente al digest.
                digest.update(chunk)
        # Separa el fichero actual del siguiente.
        digest.update(b"\0NEXT\0")
    # Devuelve únicamente el digest; el contenido analizado nunca se imprime.
    return digest.hexdigest()

# Detecta herramientas disponibles sin ejecutar scanners ni acceder a red.
def detect_tools() -> dict[str, bool]:
    # Crea un mapa estable herramienta -> disponibilidad.
    return {tool: shutil.which(tool) is not None for tool in TOOLS}

# Construye el inventario completo del repositorio.
def build_context(repo: Path) -> dict[str, Any]:
    # Resuelve la raíz real.
    repo_root = resolve_repo_root(repo)
    # Obtiene las rutas cambiadas.
    changed_files = collect_changed_files(repo_root)
    # Obtiene líneas añadidas únicamente para clasificación interna.
    added_diff = collect_added_diff(repo_root)
    # Clasifica el cambio.
    risk = classify_risk(changed_files, added_diff)
    # Detecta stack.
    stack = detect_stack(repo_root)
    # Detecta herramientas instaladas.
    tools = detect_tools()
    # Calcula una huella del estado actual para invalidar veredictos obsoletos después de cambios posteriores.
    gate_fingerprint = calculate_gate_fingerprint(repo_root, changed_files)
    # Comprueba archivos de gobierno de seguridad.
    security_files = {
        ".sabas-security.yml": (repo_root / ".sabas-security.yml").exists(),
        "SECURITY-THREAT-MODEL.md": (repo_root / "SECURITY-THREAT-MODEL.md").exists(),
        "SECURITY-RISK-ACCEPTANCE.md": (repo_root / "SECURITY-RISK-ACCEPTANCE.md").exists(),
        "AGENTS.md": (repo_root / "AGENTS.md").exists(),
    }
    # Devuelve únicamente metadatos; no incluye contenido del diff ni secretos.
    return {
        "repo_root": str(repo_root),
        "stack": stack,
        "changed_files": changed_files,
        "gate_fingerprint": gate_fingerprint,
        "risk": risk,
        "tools": tools,
        "security_files": security_files,
    }

# Define la entrada principal del programa.
def main() -> int:
    # Crea el parser de argumentos.
    parser = argparse.ArgumentParser(description="Build a non-destructive security context for Sabas Secure QA.")
    # Añade la ruta del repositorio como argumento opcional.
    parser.add_argument("--repo", default=".", help="Repository or project directory to inspect.")
    # Procesa argumentos.
    args = parser.parse_args()
    # Convierte la ruta recibida a Path.
    repo = Path(args.repo)
    # Valida que la ruta exista y sea un directorio.
    if not repo.exists() or not repo.is_dir():
        # Emite un error JSON sin traza interna innecesaria.
        print(json.dumps({"error": "repo path does not exist or is not a directory"}, ensure_ascii=False))
        # Devuelve código de error de uso.
        return 2
    # Construye el contexto.
    context = build_context(repo)
    # Imprime JSON legible y estable para Codex.
    print(json.dumps(context, ensure_ascii=False, indent=2, sort_keys=True))
    # Indica ejecución correcta.
    return 0

# Ejecuta main únicamente cuando el archivo se invoca como script.
if __name__ == "__main__":
    # Propaga el código de salida al sistema operativo.
    raise SystemExit(main())
