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
# Exige soporte explícito de los cuatro destinos.
for target in ("Codex", "Hermes", "Antigravity", "All"):
    assert target in setup

# Aísla la resolución de Hermes para validar el orden de fuentes sin depender de otras menciones del entorno.
hermes_resolver = setup[
    setup.index("function Resolve-SabasHermesSkillsTarget") : setup.index("function Repair-SabasCodexHooksEncoding")
]
# Exige consultar primero el perfil efectivo que declara la CLI de Hermes.
assert hermes_resolver.index("hermes config path") < hermes_resolver.index("$env:HERMES_HOME")
# Exige que una ruta efectiva de CLI gane frente a homes heredados o variables stale.
assert "return $CliSkillsTarget" in hermes_resolver

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
)
# Comprueba cada archivo crítico de distribución.
for relative_path in required_packaging_files:
    assert (root / relative_path).is_file(), relative_path

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

# Confirma que existe documentación dedicada a Antigravity.
assert (root / "ANTIGRAVITY.md").is_file()
