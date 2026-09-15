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
# Exige escritura .NET que evita el BOM de Windows PowerShell 5.1.
assert "System.IO.File]::WriteAllText" in setup
# Exige verificación SHA-256 del hook instalado.
assert "Get-FileHash -Algorithm SHA256" in setup
# Exige soporte explícito de los cuatro destinos.
for target in ("Codex", "Hermes", "Antigravity", "All"):
    assert target in setup

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
