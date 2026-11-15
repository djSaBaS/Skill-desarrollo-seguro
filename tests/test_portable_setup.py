# Importa Path para inspeccionar los archivos del bundle.
from pathlib import Path
# Importa sys para recibir la raíz del bundle.
import sys

# Resuelve la raíz indicada por el runner.
root = Path(sys.argv[1]).resolve()

# Lee el setup portable como texto.
setup = (root / "scripts" / "Setup-SabasSecureDev.ps1").read_text(encoding="utf-8-sig")
# Exige la ruta global oficial actual de Antigravity IDE.
assert ".gemini\\config\\skills" in setup
# Impide reintroducir la ruta global antigua que no documenta Antigravity actual.
assert ".gemini\\antigravity\\skills" not in setup
# Exige que la skill de eficiencia se complete también en Codex y Hermes.
assert "sabas-efficient-development" in setup
# Exige que hooks.json se reescriba explícitamente como UTF-8 sin BOM.
assert "System.Text.UTF8Encoding($false)" in setup
# Exige un decodificador UTF-8 estricto para no depender de la code page de Windows PowerShell 5.1.
assert "System.Text.UTF8Encoding($false, $true)" in setup
# Exige lectura binaria antes de decodificar hooks.json.
assert "System.IO.File]::ReadAllBytes($HooksFile)" in setup
# Impide volver a leer hooks.json con Get-Content, que interpreta UTF-8 sin BOM como ANSI en Windows PowerShell 5.1.
assert "Get-Content -Raw -Path $HooksFile" not in setup
# Exige escritura .NET que evita el BOM de Windows PowerShell 5.1.
assert "System.IO.File]::WriteAllText" in setup
# Exige verificación SHA-256 del hook instalado.
assert "Get-FileHash -Algorithm SHA256" in setup
# Exige soporte explícito de los cuatro destinos del setup.
for target in ("Codex", "Hermes", "Antigravity", "All"):
    # Verifica cada destino esperado.
    assert target in setup

# Aísla la resolución de Hermes para validar el orden de fuentes sin depender de otras menciones del entorno.
hermes_resolver = setup[
    setup.index("function Resolve-SabasHermesSkillsTarget") : setup.index("function Repair-SabasCodexHooksEncoding")
]
# Exige consultar el perfil declarado por Hermes antes de los fallbacks heredados.
assert hermes_resolver.index("hermes config path") < hermes_resolver.index("$env:HERMES_HOME")
# Exige conservar discovery real mediante HERMES_PLUGINS_DEBUG.
assert "HERMES_PLUGINS_DEBUG" in hermes_resolver
# Exige que el wrapper capture la salida de discovery antes de decidir por una instalación previa.
assert hermes_resolver.index("$DiscoveryOutput") < hermes_resolver.index(r"sabas-secure-qa\SKILL.md")
# Impide volver a hacer definitivo config path antes de consultar discovery.
assert "return $CliSkillsTarget" not in hermes_resolver

# Lee el desinstalador portable como texto.
uninstaller = (root / "scripts" / "Uninstall-SabasSecureDev.ps1").read_text(encoding="utf-8-sig")
# Exige que la desinstalación cubra los tres runtimes y el destino conjunto.
for target in ("Codex", "Hermes", "Antigravity", "All", "Both"):
    # Verifica cada destino compatible, incluido Both heredado.
    assert target in uninstaller
# Exige retirar también la skill de eficiencia instalada por el wrapper.
assert "sabas-efficient-development" in uninstaller
# Exige usar la misma ruta global oficial de Antigravity que el instalador.
assert ".gemini\\config\\skills" in uninstaller
# Exige helpers explícitos de UTF-8 estricto y escritura sin BOM.
assert "System.Text.UTF8Encoding($false, $true)" in uninstaller
# Exige escritura .NET sin depender de Set-Content -Encoding utf8.
assert "System.IO.File]::WriteAllText" in uninstaller

# Aísla la retirada del Stop Hook para validar que preserve hooks ajenos sin corromper Unicode.
hook_remover = uninstaller[
    uninstaller.index("function Remove-SabasCodexHook") : uninstaller.index("function Remove-SabasHermesPlugin")
]
# Exige lectura UTF-8 explícita del JSON compartido.
assert "Read-SabasUtf8Text -Path $HooksFile" in hook_remover
# Exige escritura UTF-8 sin BOM del JSON preservado.
assert "Write-SabasUtf8NoBom -Path $HooksFile" in hook_remover
# Impide reintroducir lectura ANSI implícita en el flujo de desinstalación.
assert "Get-Content -Raw -Path $HooksFile" not in hook_remover
# Impide reintroducir Set-Content -Encoding utf8 en hooks.json.
assert "Set-Content -Path $HooksFile" not in hook_remover

# Lee el runner de autopruebas.
self_test = (root / "scripts" / "Test-SabasSecureDev.ps1").read_text(encoding="utf-8-sig")
# Exige copiar archivos ocultos para que el staging de validación conserve manifiestos y marcadores.
assert "Get-ChildItem -LiteralPath $SourceRoot -Force" in self_test
# Exige excluir solamente la metadata .git del artefacto validado.
assert "$BundleEntry.Name -eq '.git'" in self_test

# Exige los archivos de packaging que deben existir también después de un git clone normal.
required_packaging_files = (
    ".codex-plugin/plugin.json",
    ".github/workflows/validate.yml",
    ".gitattributes",
    ".gitignore",
    "hermes-plugin/sabas-secure-development/.sabas-managed-plugin.json",
    "skills/sabas-efficient-development/agents/openai.yaml",
    "skills/sabas-security-bootstrap/assets/.sabas-security.yml",
    "support-skills/usuario-torpe-qa/.sabas-bundled-support.json",
    "templates/.sabas-security.yml",
    "tests/Invoke-UninstallerSmoke.ps1",
)
# Comprueba cada archivo crítico de distribución.
for relative_path in required_packaging_files:
    # Exige que el archivo exista realmente en el checkout.
    assert (root / relative_path).is_file(), relative_path

# Lee el workflow de CI para exigir cobertura Windows del desinstalador.
workflow = (root / ".github" / "workflows" / "validate.yml").read_text(encoding="utf-8")
# Exige el smoke test de desinstalación en el job Windows PowerShell 5.1.
assert "Invoke-UninstallerSmoke.ps1" in workflow
# Exige que CI deje una huella SHA-256 auditable de los componentes portables modificados.
assert "Report portable component hashes" in workflow

# Lee el actualizador remoto.
updater = (root / "scripts" / "Update-SabasSecureDev.ps1").read_text(encoding="utf-8-sig")
# Exige que el origen sea el repositorio oficial.
assert "djSaBaS/Skill-desarrollo-seguro" in updater
# Exige que el setup descargado se ejecute en modo Update.
assert "Action = 'Update'" in updater
# Exige limpieza de la carpeta temporal.
assert "finally" in updater and "Remove-Item -Recurse -Force" in updater

# Lee la documentación de la skill eficiente.
efficient_readme = (root / "skills" / "sabas-efficient-development" / "README.md").read_text(encoding="utf-8")
# Exige la ruta global oficial de Antigravity.
assert "~/.gemini/config/skills/" in efficient_readme
# Impide documentar la ruta antigua.
assert "~/.gemini/antigravity/skills/" not in efficient_readme

# Comprueba que el instalador expone selección funcional independiente del agente.
assert "[string[]]$Components" in setup
# Comprueba que el instalador mantiene el selector de grupos para uso interactivo.
assert "Selecciona qué skills instalar" in setup
# Impide ejecutar el motor de seguridad cuando el usuario solicita solo eficiencia o lanzamiento.
assert "$NeedsCoreInstaller = $HasSecurity" in setup
# Exige que la nueva skill esté disponible en Codex, Hermes y Antigravity.
assert "sabas-release-compliance" in setup
# Verifica que el actualizador reenvía la selección funcional.
assert "$SetupArguments['Components'] = $Components" in updater
# Verifica que el desinstalador puede retirar módulos sin afectar al plugin de Hermes.
assert "$RemovingSecurity" in uninstaller
# Exige el contrato completo de la nueva Agent Skill.
release_root = root / "skills" / "sabas-release-compliance"
# Comprueba la identidad de la skill y su guía auxiliar.
assert (release_root / "SKILL.md").is_file()
# Comprueba la definición del agente que permite selección automática.
assert (release_root / "agents" / "openai.yaml").is_file()
# Lee la guía original de prepublicación.
preflight = (release_root / "references" / "preflight-35.md").read_text(encoding="utf-8")
# Exige identificadores numerados consecutivos y sin duplicados para los 35 controles.
for index in range(1, 36):
    # Cada identificador comienza una nueva línea numerada.
    assert f"{index:02d}. **" in preflight
# Impide presentar los 35 controles originales como transcripción de un vídeo no verificado.
assert "not a" in preflight and "transcription" in preflight

# Lee el catálogo reforzado de controles críticos de seguridad.
five_controls = (root / "skills" / "sabas-secure-qa" / "references" / "five-security-controls.md").read_text(encoding="utf-8")
# Valida que las cinco familias tengan un contrato verificable en la documentación distribuida.
for family in ("SEC-ENV", "SEC-PROD", "SEC-RATE", "SEC-ROW", "SEC-SESS"):
    # Exige que cada familia posea requisitos y pruebas negativas explícitos.
    assert f"## {family}" in five_controls
# Comprueba que secretos reales se guarden fuera de Git y del directorio público.
assert ".env.example" in five_controls and "public_html" in five_controls
# Exige comprobar el aislamiento por servidor cuando el proyecto utilice MySQL/MariaDB.
assert "PHP/MySQL/MariaDB" in five_controls
# Exige que el limitador contemple IP de origen confiable y encabezados falsificados.
assert "X-Forwarded-For" in five_controls and "429 Too Many Requests" in five_controls
# Exige que las sesiones tengan caducidad por inactividad y duración máxima.
assert "idle timeout" in five_controls and "absolute" in five_controls
# Comprueba que las reglas se carguen al revisar código sensible.
security_skill = (root / "skills" / "sabas-secure-qa" / "SKILL.md").read_text(encoding="utf-8")
# El orquestador debe conocer la referencia de comprobaciones.
assert "references/five-security-controls.md" in security_skill
# Comprueba que la política de gate no pueda ignorar los cinco controles.
security_gates = (root / "skills" / "sabas-secure-qa" / "references" / "security-gates.md").read_text(encoding="utf-8")
# Exige el ruteo explícito de los riesgos de los controles al gate.
assert "Five control-family gates" in security_gates
# Confirma que el repositorio no permita añadir secretos .env accidentalmente.
ignore_rules = (root / ".gitignore").read_text(encoding="utf-8")
# El patrón de exclusión incluye todas las variantes y permite solo ejemplo sin datos.
assert ".env\n" in ignore_rules and ".env.*\n" in ignore_rules and "!.env.example" in ignore_rules

# Lee la plantilla segura de claves de entorno con valores ficticios.
env_template = (root / "skills" / "sabas-secure-qa" / "assets" / ".env.example").read_text(encoding="utf-8")
# El archivo versionable de ejemplo debe definir nombres sin contraseñas reales.
assert "DB_PASSWORD=" in env_template and "APP_SECRET=" in env_template
# Los campos que representan secretos deben mantenerse sin valor predeterminado.
for secret_key in ("DB_PASSWORD", "APP_SECRET", "SESSION_SIGNING_KEY", "SERVICE_API_KEY"):
    # Busca únicamente declaraciones vacías, rechazando secretos introducidos accidentalmente en el ejemplo.
    assert f"{secret_key}=\n" in env_template

# Confirma que existe documentación dedicada a Antigravity.
assert (root / "ANTIGRAVITY.md").is_file()
