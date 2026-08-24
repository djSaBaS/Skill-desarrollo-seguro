# Importa anotaciones diferidas para mantener compatibilidad con varias versiones de Python.
from __future__ import annotations

# Importa json para interpretar la salida del clasificador determinista.
import json
# Importa os para resolver el directorio de trabajo actual de Hermes.
import os
# Importa re para validar recibos y clasificar comandos sensibles sin imprimir secretos.
import re
# Importa subprocess para ejecutar el clasificador sin usar shell.
import subprocess
# Importa sys para reutilizar el mismo intérprete Python que carga el plugin.
import sys
# Importa Path para resolver rutas de forma portable entre Windows, Linux y macOS.
from pathlib import Path

# Define los niveles que requieren un gate de cierre de seguridad.
REVIEW_RISKS = {"R2", "R3", "R4"}
# Define los únicos veredictos aceptados por el recibo machine-readable.
VERDICT_VALUES = ("PASS", "PASS WITH WARNINGS", "BLOCKED")
# Define el marcador exacto del veredicto.
VERDICT_MARKER = "SABAS_SECURITY_VERDICT:"
# Define el marcador exacto de la huella del estado revisado.
FINGERPRINT_MARKER = "SABAS_SECURITY_FINGERPRINT:"

# Resuelve HERMES_HOME desde la ubicación donde Hermes cargó realmente este plugin.
def resolve_hermes_home() -> Path:
    # El propio __file__ es la evidencia más fiable porque el plugin vive en <HERMES_HOME>/plugins/<nombre>/.
    try:
        # Sube desde __init__.py a plugin, plugins y finalmente HERMES_HOME.
        plugin_home = Path(__file__).resolve().parents[2]
        # Devuelve ese home cuando conserva la estructura esperada.
        if (plugin_home / "plugins").is_dir():
            return plugin_home
    # Tolera layouts empaquetados o resoluciones de ruta inusuales sin romper el agente.
    except (IndexError, OSError):
        pass
    # Lee HERMES_HOME como segundo mecanismo para perfiles personalizados.
    configured = os.environ.get("HERMES_HOME", "").strip()
    # Devuelve el perfil explícito cuando está definido.
    if configured:
        # Expande ~ para soportar rutas configuradas manualmente.
        return Path(configured).expanduser()
    # En Windows moderno Hermes usa por defecto %LOCALAPPDATA%\hermes.
    if os.name == "nt":
        # Lee LOCALAPPDATA cuando está disponible.
        local_appdata = os.environ.get("LOCALAPPDATA", "").strip()
        # Usa la ubicación nativa documentada por releases actuales.
        if local_appdata:
            return Path(local_appdata) / "hermes"
        # Mantiene un fallback equivalente cuando LOCALAPPDATA no está expuesto.
        return Path.home() / "AppData" / "Local" / "hermes"
    # En POSIX Hermes usa ~/.hermes por defecto.
    return Path.home() / ".hermes"

# Localiza el clasificador Sabas instalado para Hermes o compartido desde Codex.
def resolve_classifier() -> Path | None:
    # Construye la ubicación nativa de la skill en Hermes.
    hermes_classifier = resolve_hermes_home() / "skills" / "sabas-secure-qa" / "scripts" / "security_context.py"
    # Prioriza la copia nativa de Hermes cuando existe.
    if hermes_classifier.is_file():
        # Devuelve la ruta verificada.
        return hermes_classifier
    # Construye la ubicación compartida convencional usada por Codex y también soportada por Hermes.
    shared_classifier = Path.home() / ".agents" / "skills" / "sabas-secure-qa" / "scripts" / "security_context.py"
    # Devuelve la copia compartida cuando está disponible.
    if shared_classifier.is_file():
        # Conserva compatibilidad con instalaciones Both o Codex-first.
        return shared_classifier
    # Indica que no existe evidencia determinista suficiente.
    return None

# Ejecuta el clasificador Sabas sobre el repositorio actual.
def classify_repository(cwd: str) -> dict | None:
    # Localiza el script de clasificación instalado.
    classifier = resolve_classifier()
    # Sale de forma no bloqueante si el componente principal no está instalado.
    if classifier is None:
        # Evita falsos bloqueos por una instalación incompleta.
        return None
    # Ejecuta el clasificador sin shell para evitar expansión o inyección accidental.
    try:
        # Lanza Python con la ruta del repositorio como argumento explícito.
        result = subprocess.run(
            # Reutiliza el intérprete de Hermes para evitar discrepancias de entorno.
            [sys.executable, str(classifier), "--repo", cwd],
            # Captura stdout/stderr para que el hook no ensucie la interfaz.
            capture_output=True,
            # Solicita cadenas de texto en lugar de bytes.
            text=True,
            # Limita la espera para no bloquear un cierre de Hermes indefinidamente.
            timeout=20,
            # Permite inspeccionar manualmente el código de salida.
            check=False,
        )
    # Tolera timeouts o errores del sistema sin convertir el plugin en un punto único de fallo.
    except (subprocess.TimeoutExpired, OSError):
        # Devuelve ausencia de evidencia y deja que actúen las demás capas.
        return None
    # Ignora una clasificación que terminó con error.
    if result.returncode != 0:
        # No interpreta salida potencialmente incompleta.
        return None
    # Intenta convertir la salida JSON del clasificador.
    try:
        # Devuelve el objeto estructurado de contexto.
        return json.loads(result.stdout)
    # Captura únicamente un formato JSON inválido.
    except json.JSONDecodeError:
        # Evita utilizar evidencia corrupta.
        return None

# Extrae R0-R4 de las formas de salida soportadas por security_context.py.
def extract_risk(context: dict) -> str:
    # Obtiene la clave principal de riesgo.
    direct = context.get("risk")
    # Acepta la forma simple R0-R4.
    if isinstance(direct, str) and direct in {"R0", "R1", "R2", "R3", "R4"}:
        # Devuelve la clasificación directa.
        return direct
    # Acepta la forma estructurada usada por versiones recientes.
    if isinstance(direct, dict):
        # Obtiene el nivel anidado.
        nested = direct.get("risk")
        # Comprueba que el nivel sea válido.
        if isinstance(nested, str) and nested in {"R0", "R1", "R2", "R3", "R4"}:
            # Devuelve el nivel normalizado.
            return nested
    # Obtiene candidatos como fallback compatible.
    candidates = context.get("risk_candidates", [])
    # Empieza por el nivel mínimo.
    maximum = 0
    # Recorre únicamente listas válidas.
    if isinstance(candidates, list):
        # Evalúa cada candidato sin confiar en su forma exacta.
        for candidate in candidates:
            # Serializa objetos para poder buscar las etiquetas R0-R4.
            text = json.dumps(candidate, ensure_ascii=False) if isinstance(candidate, dict) else str(candidate)
            # Recorre niveles posibles.
            for level in range(5):
                # Detecta la etiqueta dentro del candidato.
                if f"R{level}" in text:
                    # Conserva el máximo observado.
                    maximum = max(maximum, level)
    # Devuelve el nivel de respaldo.
    return f"R{maximum}"

# Comprueba que la respuesta final esté ligada exactamente al fingerprint actual.
def has_valid_security_receipt(final_response: str, expected_fingerprint: str) -> bool:
    # Rechaza huellas vacías porque no demuestran qué estado fue revisado.
    if not expected_fingerprint:
        # Obliga a regenerar el contexto antes de cerrar.
        return False
    # Construye los veredictos válidos escapados para regex.
    allowed = "|".join(re.escape(value) for value in VERDICT_VALUES)
    # Busca una única línea exacta de veredicto.
    verdict_matches = re.findall(
        # Exige marcador, valor permitido y fin de línea.
        rf"(?m)^{re.escape(VERDICT_MARKER)}\s*({allowed})\s*$",
        # Analiza exclusivamente el borrador de respuesta final.
        final_response,
    )
    # Exige exactamente un veredicto estructurado.
    if len(verdict_matches) != 1:
        # Rechaza ejemplos, duplicados o ausencia del recibo.
        return False
    # Busca exactamente la huella actual en línea propia.
    fingerprint_matches = re.findall(
        # Exige el marcador y el SHA-256 actual literal.
        rf"(?m)^{re.escape(FINGERPRINT_MARKER)}\s*{re.escape(expected_fingerprint)}\s*$",
        # Analiza el mismo borrador final.
        final_response,
    )
    # Devuelve verdadero solo para una coincidencia exacta y única.
    return len(fingerprint_matches) == 1

# Extrae una ruta potencial de herramientas de escritura de Hermes.
def extract_target_path(args: dict) -> str:
    # Recorre nombres habituales usados por write_file, patch y herramientas compatibles.
    for key in ("path", "file_path", "filepath", "target", "destination"):
        # Obtiene el valor sin asumir que exista.
        value = args.get(key)
        # Devuelve únicamente cadenas no vacías.
        if isinstance(value, str) and value.strip():
            # Normaliza a minúsculas para comparaciones de política.
            return value.strip().lower()
    # Devuelve cadena vacía cuando no hay ruta observable.
    return ""

# Decide si una ruta requiere aprobación humana por afectar configuración o secretos.
def path_requires_approval(path_text: str) -> bool:
    # Normaliza separadores para comparar rutas de Windows y POSIX de forma uniforme.
    normalized = path_text.replace("\\", "/").lower()
    # Define nombres y fragmentos sensibles que nunca deberían modificarse silenciosamente.
    sensitive_fragments = (
        # Protege ficheros de variables de entorno y secretos.
        "/.env",
        # Protege material de clave privada SSH.
        "id_rsa",
        # Protege claves privadas PEM/PFX/P12.
        ".pem",
        ".pfx",
        ".p12",
        # Protege ficheros explícitos de credenciales o secretos.
        "credentials",
        "secrets",
        # Protege la configuración de Hermes en layout POSIX/heredado.
        "/.hermes/config.yaml",
        # Protege también el layout nativo Windows bajo AppData/Local/hermes.
        "/hermes/config.yaml",
        # Protege el plugin Sabas instalado en cualquier layout de home.
        "/hermes/plugins/sabas-secure-development/",
        # Conserva compatibilidad explícita con ~/.hermes.
        "/.hermes/plugins/sabas-secure-development/",
        # Protege el gate de Codex cuando ambas plataformas comparten la máquina.
        "/.codex/hooks/",
        # Protege las skills Sabas compartidas.
        "/.agents/skills/sabas-",
    )
    # Protege también un `.env` relativo que no contiene separador inicial.
    if normalized == ".env" or normalized.startswith(".env."):
        # Exige aprobación humana para variables de entorno locales.
        return True
    # Devuelve verdadero si aparece cualquier fragmento sensible.
    return any(fragment in normalized for fragment in sensitive_fragments)

# Clasifica comandos terminales en block, review o allow sin registrar su contenido completo.
def classify_terminal_command(command: str) -> str:
    # Normaliza espacios y mayúsculas para reglas conservadoras.
    normalized = " ".join(command.strip().lower().split())
    # Permite comandos vacíos sin generar ruido.
    if not normalized:
        # No existe operación que revisar.
        return "allow"
    # Define patrones catastróficos que no deben ejecutarse desde el agente.
    catastrophic_patterns = (
        # Bloquea borrado recursivo de la raíz POSIX.
        r"\brm\s+-[^\n]*r[^\n]*f[^\n]*\s+/(?:\s|$|\*)",
        # Bloquea borrado recursivo explícito de la raíz del usuario.
        r"\brm\s+-[^\n]*r[^\n]*f[^\n]*\s+~(?:/|\s|$)",
        # Bloquea formateo directo de una unidad Windows.
        r"\bformat\s+[a-z]:",
        # Bloquea mkfs sobre dispositivos reales.
        r"\bmkfs(?:\.[a-z0-9]+)?\s+/dev/",
        # Bloquea escritura destructiva directa al disco mediante dd.
        r"\bdd\s+[^\n]*\bof=/dev/(?:sd|nvme|vd|hd)",
        # Bloquea Remove-Item recursivo sobre la raíz de una unidad Windows.
        r"\bremove-item\b[^\n]*-recurse[^\n]*-force[^\n]*\b[a-z]:\\(?:\s|$|\*)",
    )
    # Recorre las reglas catastróficas.
    for pattern in catastrophic_patterns:
        # Comprueba cada patrón sin evaluar shell.
        if re.search(pattern, normalized, re.IGNORECASE):
            # Ordena un bloqueo duro.
            return "block"
    # Define operaciones peligrosas pero que pueden ser legítimas con aprobación explícita.
    approval_patterns = (
        # Protege reescritura destructiva del worktree.
        r"\bgit\s+reset\s+--hard\b",
        # Protege limpieza destructiva de archivos no rastreados.
        r"\bgit\s+clean\s+-[^\n]*f",
        # Protege push forzado de historia.
        r"\bgit\s+push\b[^\n]*(?:--force|-f\b)",
        # Protege borrado de bases o tablas.
        r"\bdrop\s+(?:database|table)\b",
        # Protege TRUNCATE porque elimina datos de forma masiva.
        r"\btruncate\s+table\b",
        # Protege DELETE sin WHERE de forma conservadora.
        r"\bdelete\s+from\s+[a-z0-9_`.]+\s*;?$",
        # Protege permisos globalmente escribibles.
        r"\bchmod\s+(?:-r\s+)?777\b",
        # Protege ejecución directa de código descargado.
        r"(?:curl|wget)\b[^\n|]*\|\s*(?:sh|bash|zsh|powershell|pwsh)\b",
        # Protege Invoke-Expression alimentado por red.
        r"\b(?:invoke-webrequest|iwr|curl)\b[^\n]*\|[^\n]*\b(?:invoke-expression|iex)\b",
        # Protege lecturas explícitas de .env con herramientas habituales.
        r"\b(?:cat|type|get-content)\b[^\n]*\.env(?:\b|\.)",
        # Protege comandos que deshabilitan controles de seguridad comunes.
        r"\bset-executionpolicy\b[^\n]*(?:bypass|unrestricted)\b",
    )
    # Recorre las operaciones que necesitan una decisión humana.
    for pattern in approval_patterns:
        # Comprueba coincidencias sin ejecutar el comando.
        if re.search(pattern, normalized, re.IGNORECASE):
            # Escala al gate de aprobación de Hermes.
            return "review"
    # Permite comandos que no coinciden con reglas de alto riesgo.
    return "allow"

# Hook ejecutado antes de cada llamada a herramientas de Hermes.
def before_tool_call(tool_name: str, args: dict, task_id: str = "", **kwargs):
    # Descarta metadatos que no se usan para mantener una firma compatible con futuras versiones.
    del task_id, kwargs
    # Normaliza argumentos inesperados a un diccionario vacío.
    safe_args = args if isinstance(args, dict) else {}
    # Interviene únicamente en terminal, donde Hermes documenta el veto pre_tool_call.
    if tool_name == "terminal":
        # Obtiene el comando sin asumir un único nombre de campo.
        command = safe_args.get("command") or safe_args.get("cmd") or ""
        # Clasifica el comando sin ejecutarlo.
        decision = classify_terminal_command(str(command))
        # Bloquea operaciones catastróficas inequívocas.
        if decision == "block":
            # Usa la directiva más antigua y compatible del contrato pre_tool_call.
            return {"action": "block", "message": "Sabas Tool Guard bloqueó una operación terminal catastrófica."}
        # Para operaciones peligrosas pero potencialmente legítimas usa también block como mínimo común entre versiones.
        if decision == "review":
            # El usuario puede ejecutar manualmente la operación después de revisarla; el agente no la hace silenciosamente.
            return {"action": "block", "message": "Sabas Tool Guard bloqueó una operación sensible. Revísala y ejecútala manualmente si realmente es necesaria."}
        # Permite terminal normal.
        return None
    # Examina rutas sensibles en herramientas de archivos sin asumir un nombre único de tool.
    target_path = extract_target_path(safe_args)
    # Bloquea acceso automatizado a secretos/configuración Sabas cuando la herramienta expone una ruta sensible.
    if target_path and path_requires_approval(target_path):
        # Usa block para funcionar incluso en versiones que no implementan escalado de aprobación.
        return {"action": "block", "message": "Sabas Tool Guard bloqueó acceso automatizado a una ruta sensible. Revísala manualmente."}
    # No interviene en herramientas normales.
    return None

# Hook ejecutado justo antes de que Hermes acepte la respuesta final tras editar código.
def before_verify(
    session_id: str,
    platform: str,
    model: str,
    coding: bool,
    attempt: int,
    final_response: str,
    changed_paths: list,
    **kwargs,
):
    # Descarta metadatos informativos que no afectan a la política.
    del session_id, platform, model, kwargs
    # Ignora turnos que Hermes no considera de programación.
    if not coding:
        # No añade una continuación innecesaria.
        return None
    # Ignora eventos sin rutas modificadas por diseño defensivo.
    if not changed_paths:
        # No existe cambio observable que ligar a un fingerprint.
        return None
    # Clasifica el repositorio actual con la misma lógica usada por Codex.
    context = classify_repository(os.getcwd())
    # Si no puede obtener evidencia determinista, pide una única revisión explícita en el primer intento.
    if not context:
        # Evita repetir el mismo mensaje hasta agotar el límite de nudges.
        if attempt == 0:
            # Mantiene el turno abierto para que Hermes pueda recuperar la instalación o explicar la limitación.
            return {
                "action": "continue",
                "message": "Sabas Secure Gate no pudo ejecutar security_context.py. Verifica la instalación de sabas-secure-qa y no declares PASS sin evidencia determinista.",
            }
        # Permite que el límite nativo de Hermes gestione intentos posteriores.
        return None
    # Extrae el nivel de riesgo actual.
    risk = extract_risk(context)
    # Permite cerrar R0/R1 porque no requieren recibo final obligatorio.
    if risk not in REVIEW_RISKS:
        # Conserva el flujo normal de Hermes.
        return None
    # Obtiene la huella criptográfica del estado actual.
    fingerprint = str(context.get("gate_fingerprint") or "")
    # Permite finalizar cuando el borrador contiene un recibo válido para esa huella.
    if has_valid_security_receipt(str(final_response or ""), fingerprint):
        # El gate queda satisfecho.
        return None
    # Mantiene el turno abierto para ejecutar/terminar la revisión de seguridad.
    return {
        # Usa la directiva documentada para continuar la conversación interna.
        "action": "continue",
        # Da instrucciones concretas sin afirmar que ninguna prueba ya haya pasado.
        "message": (
            f"Sabas Secure Gate detectó cambios de riesgo {risk} sin un recibo válido para el estado actual. "
            "Aplica sabas-secure-qa al cambio, ejecuta las verificaciones aplicables, corrige bloqueantes y vuelve a ejecutar "
            "security_context.py inmediatamente antes de terminar. Incluye exactamente una línea SABAS_SECURITY_VERDICT: "
            "PASS, PASS WITH WARNINGS o BLOCKED y una línea SABAS_SECURITY_FINGERPRINT: con el gate_fingerprint recién calculado."
        ),
    }

# Registra los guardrails dentro del ciclo nativo de Hermes Agent.
def register(ctx):
    # Registra cada hook de forma independiente para tolerar versiones de Hermes con superficies distintas.
    try:
        # pre_tool_call existe en versiones con el sistema de plugins y permite un veto `block`.
        ctx.register_hook("pre_tool_call", before_tool_call)
    except Exception:
        # Una versión antigua no debe impedir que el resto del plugin se cargue.
        pass
    # pre_verify es más reciente; se degrada de forma segura cuando la versión instalada aún no lo expone.
    try:
        # Registra el gate de cierre R2+ cuando está disponible.
        ctx.register_hook("pre_verify", before_verify)
    except Exception:
        # verify_on_stop y las skills siguen aportando protección aunque este hook no exista.
        pass
