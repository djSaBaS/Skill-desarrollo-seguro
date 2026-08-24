# Importa anotaciones diferidas para mantener tipos modernos sin efectos en runtime.
from __future__ import annotations

# Importa json para leer el evento de hook y emitir la respuesta esperada por Codex.
import json
# Importa os para resolver la ubicación instalada de las skills personales.
import os
# Importa re para validar marcadores machine-readable sin aceptar coincidencias ambiguas.
import re
# Importa subprocess para ejecutar el clasificador determinista del bundle.
import subprocess
# Importa sys para leer stdin y devolver la respuesta del hook.
import sys
# Importa Path para construir rutas de forma portable.
from pathlib import Path

# Define los niveles que justifican una verificación de cierre automática.
REVIEW_RISKS = {"R2", "R3", "R4"}
# Define el marcador explícito del veredicto de seguridad.
VERDICT_MARKER = "SABAS_SECURITY_VERDICT:"
# Define el marcador que liga ese veredicto al estado actual del cambio.
FINGERPRINT_MARKER = "SABAS_SECURITY_FINGERPRINT:"
# Define los únicos valores de veredicto que el hook acepta como recibo machine-readable.
VERDICT_VALUES = ("PASS", "PASS WITH WARNINGS", "BLOCKED")

# Localiza el clasificador instalado dentro de la skill personal.
def resolve_classifier() -> Path:
    # Obtiene el HOME de forma portable y sin asumir una letra de unidad de Windows.
    home = Path.home()
    # Construye la ruta documentada para skills personales de Codex.
    return home / ".agents" / "skills" / "sabas-secure-qa" / "scripts" / "security_context.py"

# Ejecuta el clasificador y devuelve su JSON cuando está disponible.
def classify_repository(cwd: str) -> dict | None:
    # Resuelve la ruta del script de clasificación.
    classifier = resolve_classifier()
    # Continúa de forma no bloqueante cuando la skill no está correctamente instalada.
    if not classifier.is_file():
        # Devuelve ausencia de evidencia para no crear un bucle de hook.
        return None
    # Ejecuta el mismo intérprete de Python que está ejecutando este hook.
    try:
        # Lanza el clasificador sin shell y con límite temporal.
        result = subprocess.run(
            # Pasa la ruta del repositorio de forma explícita.
            [sys.executable, str(classifier), "--repo", cwd],
            # Captura stdout para interpretar el contexto sin ensuciar la salida del hook.
            capture_output=True,
            # Solicita texto UTF-8 manejado por Python.
            text=True,
            # Limita la ejecución para que el hook no pueda bloquear indefinidamente el cierre.
            timeout=20,
            # No lanza excepción automática por un código de salida no cero.
            check=False,
        )
    # Captura timeout o error del sistema para que un fallo del guardrail no cree un bucle de cierre.
    except (subprocess.TimeoutExpired, OSError):
        # Devuelve ausencia de evidencia y deja la decisión al gate conversacional normal.
        return None
    # Ignora la clasificación cuando el comando no pudo completarse correctamente.
    if result.returncode != 0:
        # Devuelve ausencia de evidencia y deja actuar al gate conversacional normal.
        return None
    # Intenta interpretar la salida como JSON.
    try:
        # Devuelve el objeto de contexto generado por la skill.
        return json.loads(result.stdout)
    # Captura únicamente errores de formato JSON esperables.
    except json.JSONDecodeError:
        # Devuelve ausencia de evidencia para evitar falsos bloqueos.
        return None

# Extrae el máximo nivel de riesgo indicado por el clasificador.
def extract_risk(context: dict) -> str:
    # Prueba primero la clave de riesgo final si existe.
    direct = context.get("risk")
    # Devuelve el valor cuando ya usa el formato R0-R4.
    if isinstance(direct, str) and direct in {"R0", "R1", "R2", "R3", "R4"}:
        # Conserva la clasificación directa.
        return direct
    # Admite el objeto estructurado producido por security_context.py en V0.5.4.
    if isinstance(direct, dict):
        # Obtiene el nivel anidado sin confiar en otras claves del objeto.
        nested = direct.get("risk")
        # Valida que el valor anidado sea uno de los niveles conocidos.
        if isinstance(nested, str) and nested in {"R0", "R1", "R2", "R3", "R4"}:
            # Devuelve la clasificación determinista del script.
            return nested
    # Obtiene candidatos de riesgo cuando el script expone el detalle en lugar de un valor final.
    candidates = context.get("risk_candidates", [])
    # Inicializa el máximo como el nivel más bajo.
    maximum = 0
    # Recorre únicamente una lista válida.
    if isinstance(candidates, list):
        # Evalúa cada candidato de manera defensiva.
        for candidate in candidates:
            # Convierte a texto para tolerar una representación simple o estructurada.
            text = json.dumps(candidate, ensure_ascii=False) if isinstance(candidate, dict) else str(candidate)
            # Busca todos los niveles R0-R4 presentes en el candidato.
            for level in range(5):
                # Eleva el máximo cuando encuentra una señal superior.
                if f"R{level}" in text:
                    # Conserva el mayor nivel observado.
                    maximum = max(maximum, level)
    # Devuelve la clasificación construida.
    return f"R{maximum}"

# Comprueba que el último mensaje contenga un recibo válido ligado a la huella actual.
def has_valid_security_receipt(last_message: str, expected_fingerprint: str) -> bool:
    # Rechaza una huella vacía porque no puede demostrar correspondencia con el cambio actual.
    if not expected_fingerprint:
        # Obliga a una nueva pasada del gate cuando falta la evidencia determinista.
        return False
    # Escapa los valores permitidos antes de construir la expresión regular.
    allowed_verdicts = "|".join(re.escape(value) for value in VERDICT_VALUES)
    # Construye una expresión que acepta únicamente los tres veredictos documentados.
    verdict_pattern = re.compile(
        # Exige el prefijo exacto seguido de un valor permitido y fin de línea.
        rf"(?m)^{re.escape(VERDICT_MARKER)}\s*({allowed_verdicts})\s*$"
    )
    # Comprueba que exista exactamente un veredicto estructurado en una línea propia.
    if verdict_pattern.search(last_message) is None:
        # Rechaza menciones narrativas o ejemplos que contengan solo el texto del marcador.
        return False
    # Escapa la huella porque se usa dentro de una expresión regular.
    escaped_fingerprint = re.escape(expected_fingerprint)
    # Construye el patrón de huella exacta para el estado actual.
    fingerprint_pattern = re.compile(
        # Exige una línea propia para reducir coincidencias accidentales en prosa.
        rf"(?m)^{re.escape(FINGERPRINT_MARKER)}\s*{escaped_fingerprint}\s*$"
    )
    # Devuelve verdadero únicamente cuando la huella coincide exactamente.
    return fingerprint_pattern.search(last_message) is not None

# Determina si existe superficie ejecutable cambiada suficiente para aplicar el gate.
def has_changed_surface(context: dict) -> bool:
    # Revisa claves habituales producidas por el clasificador actual.
    for key in ("changed_files", "files", "changed"):
        # Obtiene el valor sin asumir su forma exacta.
        value = context.get(key)
        # Considera que una colección no vacía representa cambios detectados.
        if isinstance(value, (list, dict)) and bool(value):
            # Confirma que hay superficie que merece evaluación.
            return True
    # Usa el riesgo como respaldo porque R2+ ya implica señales de cambio relevantes.
    return extract_risk(context) in REVIEW_RISKS

# Ejecuta la lógica principal del hook Stop.
def main() -> int:
    # Lee exactamente un objeto JSON desde stdin como define el contrato de hooks de Codex.
    raw = sys.stdin.read()
    # Evita fallar si una invocación inesperada llega sin entrada.
    if not raw.strip():
        # Emite un objeto JSON vacío que permite finalizar normalmente.
        print("{}")
        # Devuelve éxito técnico del hook.
        return 0
    # Intenta interpretar el evento recibido.
    try:
        # Convierte la entrada en un diccionario Python.
        event = json.loads(raw)
    # Captura una entrada corrupta sin bloquear el trabajo del usuario.
    except json.JSONDecodeError:
        # Emite respuesta neutra.
        print("{}")
        # Devuelve éxito para que Codex no trate el hook como averiado.
        return 0
    # Evita ciclos: un Stop ya continuado por este hook no se vuelve a continuar automáticamente.
    if bool(event.get("stop_hook_active")):
        # Permite finalizar la segunda pasada.
        print("{}")
        # Devuelve éxito.
        return 0
    # Obtiene el último mensaje del agente sin asumir que siempre exista.
    last_message = str(event.get("last_assistant_message") or "")
    # Obtiene el cwd comunicado por Codex o usa el directorio del proceso como respaldo.
    cwd = str(event.get("cwd") or os.getcwd())
    # Clasifica el repositorio mediante la misma lógica determinista usada por la skill.
    context = classify_repository(cwd)
    # No bloquea si no existe evidencia suficiente para clasificar con fiabilidad.
    if not context:
        # Emite respuesta neutra.
        print("{}")
        # Devuelve éxito.
        return 0
    # Extrae el nivel de riesgo de la evidencia disponible.
    risk = extract_risk(context)
    # Permite cerrar cambios sin superficie ejecutable relevante o por debajo de R2.
    if risk not in REVIEW_RISKS or not has_changed_surface(context):
        # Emite respuesta neutra.
        print("{}")
        # Devuelve éxito.
        return 0
    # Obtiene la huella calculada sobre el estado actual del repositorio.
    expected_fingerprint = str(context.get("gate_fingerprint") or "")
    # Permite finalizar únicamente si veredicto y huella corresponden al estado actual.
    if has_valid_security_receipt(last_message, expected_fingerprint):
        # Emite respuesta neutra porque el gate ya se evaluó sobre este cambio.
        print("{}")
        # Devuelve éxito técnico.
        return 0
    # Construye una instrucción corta y accionable para una única continuación de seguridad.
    reason = (
        f"Sabas Secure Completion Gate detectó cambios de riesgo {risk} sin un recibo válido para el estado actual. "
        "Antes de cerrar este turno, aplica $sabas-secure-qa al cambio actual, ejecuta las verificaciones "
        "aplicables, corrige los bloqueantes dentro del alcance y vuelve a ejecutar security_context.py al final. "
        "Termina con una línea SABAS_SECURITY_VERDICT usando PASS, PASS WITH WARNINGS o BLOCKED y otra línea "
        "SABAS_SECURITY_FINGERPRINT usando exactamente el gate_fingerprint recién calculado. "
        "No reutilices una huella anterior ni marques como pasada una comprobación no ejecutada."
    )
    # Emite la forma documentada para pedir a Codex una continuación del turno.
    print(json.dumps({"decision": "block", "reason": reason}, ensure_ascii=False))
    # Devuelve éxito técnico: la decisión de continuar está expresada en el JSON.
    return 0

# Ejecuta main únicamente cuando el fichero se usa como programa.
if __name__ == "__main__":
    # Propaga el código de salida al proceso del hook.
    raise SystemExit(main())
