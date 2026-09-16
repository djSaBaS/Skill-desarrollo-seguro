# Declara la raiz del bundle como parametro opcional para CI y ejecucion manual.
param(
    # Usa el padre de tests por defecto.
    [string]$BundleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

# Activa comprobaciones estrictas para que el smoke test no oculte errores.
Set-StrictMode -Version Latest
# Convierte errores PowerShell en fallos terminantes.
$ErrorActionPreference = 'Stop'

# Exige Windows porque el objetivo es reproducir Windows PowerShell y paths nativos.
if ($env:OS -ne 'Windows_NT') {
    # Informa del skip deliberado en otros sistemas.
    Write-Host 'HERMES_INSTALLER_SMOKE: SKIP (Windows only)'
    # Devuelve exito porque Linux tiene su propia validacion de bundle.
    exit 0
}

# Crea una raiz temporal aislada para no tocar la instalacion Hermes real.
$TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('sabas-hermes-installer-smoke-' + [System.Guid]::NewGuid().ToString('N'))
# Define un home que `hermes config path` declarara como perfil de configuracion.
$ConfigHermesHome = Join-Path $TempRoot 'config-home'
# Define otro home que discovery confirmara como el perfil realmente escaneado.
$DiscoveryHermesHome = Join-Path $TempRoot 'discovery-home'
# Define un directorio temporal para la CLI falsa.
$FakeBin = Join-Path $TempRoot 'bin'
# Define backups temporales del instalador core.
$FakeBackups = Join-Path $TempRoot 'backups'
# Crea las carpetas del fixture.
New-Item -ItemType Directory -Force -Path $ConfigHermesHome, $DiscoveryHermesHome, $FakeBin, $FakeBackups | Out-Null

# Conserva variables de entorno que se modificaran durante el fixture.
$PreviousPath = $env:PATH
# Conserva HERMES_HOME real.
$PreviousHermesHome = $env:HERMES_HOME
# Conserva el override de backups real.
$PreviousBackupRoot = $env:SABAS_SECURE_BACKUP_ROOT
# Conserva el home de configuracion del fake si existia.
$PreviousFakeConfigHome = $env:FAKE_HERMES_CONFIG_HOME
# Conserva el home de discovery del fake si existia.
$PreviousFakeDiscoveryHome = $env:FAKE_HERMES_DISCOVERY_HOME

# Garantiza limpieza y restauracion aunque el instalador falle.
try {
    # Define el backend Python de una CLI Hermes minima y determinista.
    $FakeHermesPython = Join-Path $FakeBin 'fake_hermes.py'
    # Escribe la CLI falsa en UTF-8.
    @'
import os
import sys
from pathlib import Path

config_home = Path(os.environ["FAKE_HERMES_CONFIG_HOME"])
discovery_home = Path(os.environ["FAKE_HERMES_DISCOVERY_HOME"])
args = sys.argv[1:]
plugin = discovery_home / "plugins" / "sabas-secure-development"

if args == ["--version"]:
    print("[plugins] diagnostic warning on stderr must not abort PowerShell 5.1", file=sys.stderr)
    print("hermes 0.test")
    raise SystemExit(0)
if args == ["config", "path"]:
    print(config_home / "config.yaml")
    raise SystemExit(0)
if args == ["profile", "list"]:
    print("default *")
    raise SystemExit(0)
if args == ["plugins", "-h"]:
    print("usage: hermes plugins {install,update,remove,list,enable,disable}")
    raise SystemExit(0)
if args == ["plugins", "enable", "sabas-secure-development"]:
    if not (plugin / "plugin.yaml").is_file() or not (plugin / "__init__.py").is_file():
        print("plugin not found", file=sys.stderr)
        raise SystemExit(2)
    print("enabled sabas-secure-development")
    raise SystemExit(0)
if args == ["plugins", "disable", "sabas-secure-development"]:
    print("disabled sabas-secure-development")
    raise SystemExit(0)
if args == ["plugins", "enable", "security-guidance"]:
    print("security-guidance not installed", file=sys.stderr)
    raise SystemExit(2)
if args == ["plugins", "list", "--plain", "--no-bundled"]:
    if (plugin / "plugin.yaml").is_file():
        print("sabas-secure-development enabled 0.5.4 user")
    raise SystemExit(0)
if args == ["plugins", "list"]:
    if os.environ.get("HERMES_PLUGINS_DEBUG") == "1":
        print("[plugins] DEBUG HERMES_PLUGINS_DEBUG=1", file=sys.stderr)
        print(f"[plugins] scanning: {discovery_home / 'plugins'}", file=sys.stderr)
    print(f"scan user plugins: {discovery_home / 'plugins'}")
    if (plugin / "plugin.yaml").is_file():
        print("sabas-secure-devel… enabled 0.5.4 Security guardrails user")
    raise SystemExit(0)
if len(args) >= 4 and args[:2] == ["config", "set"]:
    print("configured")
    raise SystemExit(0)
print("unsupported fake Hermes command: " + " ".join(args), file=sys.stderr)
raise SystemExit(2)
'@ | Set-Content -Path $FakeHermesPython -Encoding utf8
    # Define un wrapper .cmd para que Get-Command hermes funcione como en Windows real.
    $FakeHermesCmd = Join-Path $FakeBin 'hermes.cmd'
    # Escribe el wrapper usando py -3 cuando existe y python como fallback.
    if (Get-Command py -ErrorAction SilentlyContinue) {
        # Usa el launcher estandar de Windows.
        '@echo off' + "`r`n" + 'py -3 "%~dp0fake_hermes.py" %*' | Set-Content -Path $FakeHermesCmd -Encoding ascii
    }
    else {
        # Usa python directo en runners sin py.exe.
        '@echo off' + "`r`n" + 'python "%~dp0fake_hermes.py" %*' | Set-Content -Path $FakeHermesCmd -Encoding ascii
    }
    # Hace que HERMES_HOME sea un candidato distinto al config path y coincida con discovery real.
    $env:HERMES_HOME = $DiscoveryHermesHome
    # Expone al fake el perfil declarado por config path.
    $env:FAKE_HERMES_CONFIG_HOME = $ConfigHermesHome
    # Expone al fake el perfil realmente escaneado.
    $env:FAKE_HERMES_DISCOVERY_HOME = $DiscoveryHermesHome
    # Aisla tambien los backups del instalador core.
    $env:SABAS_SECURE_BACKUP_ROOT = $FakeBackups
    # Coloca primero la CLI falsa sin ocultar herramientas del sistema.
    $env:PATH = $FakeBin + [System.IO.Path]::PathSeparator + $PreviousPath
    # Define el setup portable real que se quiere probar de extremo a extremo.
    $Setup = Join-Path $BundleRoot 'scripts\Setup-SabasSecureDev.ps1'
    # Ejecuta una instalacion Hermes completa sin red ni skills externas.
    & $Setup -Target Hermes
    # Exige que la skill principal haya terminado en el home confirmado por discovery.
    if (-not (Test-Path (Join-Path $DiscoveryHermesHome 'skills\sabas-secure-qa\SKILL.md'))) { throw 'Smoke test: sabas-secure-qa was not installed in discovery home.' }
    # Exige que la skill de eficiencia siga el mismo home confirmado.
    if (-not (Test-Path (Join-Path $DiscoveryHermesHome 'skills\sabas-efficient-development\SKILL.md'))) { throw 'Smoke test: sabas-efficient-development was not installed in discovery home.' }
    # Exige que la skill de eficiencia no haya quedado en el perfil declarado pero no escaneado.
    if (Test-Path (Join-Path $ConfigHermesHome 'skills\sabas-efficient-development\SKILL.md')) { throw 'Smoke test: sabas-efficient-development was installed in stale config home.' }
    # Exige que usuario-torpe-qa este presente en el home confirmado.
    if (-not (Test-Path (Join-Path $DiscoveryHermesHome 'skills\usuario-torpe-qa\SKILL.md'))) { throw 'Smoke test: usuario-torpe-qa was not installed.' }
    # Exige el manifiesto del plugin en el home realmente escaneado.
    if (-not (Test-Path (Join-Path $DiscoveryHermesHome 'plugins\sabas-secure-development\plugin.yaml'))) { throw 'Smoke test: Hermes plugin manifest was not installed.' }
    # Exige el codigo del plugin.
    if (-not (Test-Path (Join-Path $DiscoveryHermesHome 'plugins\sabas-secure-development\__init__.py'))) { throw 'Smoke test: Hermes plugin code was not installed.' }
    # Exige el marcador de propiedad que permite limpiezas futuras sin borrar plugins ajenos.
    if (-not (Test-Path (Join-Path $DiscoveryHermesHome 'plugins\sabas-secure-development\.sabas-managed-plugin.json'))) { throw 'Smoke test: Hermes plugin ownership marker was not installed.' }
    # Emite un marcador inequívoco de exito para CI.
    Write-Host 'HERMES_INSTALLER_SMOKE: PASS'
}
finally {
    # Restaura PATH incluso si el test falla.
    $env:PATH = $PreviousPath
    # Restaura o elimina HERMES_HOME segun su estado previo.
    if ($null -eq $PreviousHermesHome) { Remove-Item Env:HERMES_HOME -ErrorAction SilentlyContinue } else { $env:HERMES_HOME = $PreviousHermesHome }
    # Restaura o elimina el override de backups.
    if ($null -eq $PreviousBackupRoot) { Remove-Item Env:SABAS_SECURE_BACKUP_ROOT -ErrorAction SilentlyContinue } else { $env:SABAS_SECURE_BACKUP_ROOT = $PreviousBackupRoot }
    # Restaura o elimina el home de configuracion del fake.
    if ($null -eq $PreviousFakeConfigHome) { Remove-Item Env:FAKE_HERMES_CONFIG_HOME -ErrorAction SilentlyContinue } else { $env:FAKE_HERMES_CONFIG_HOME = $PreviousFakeConfigHome }
    # Restaura o elimina el home de discovery del fake.
    if ($null -eq $PreviousFakeDiscoveryHome) { Remove-Item Env:FAKE_HERMES_DISCOVERY_HOME -ErrorAction SilentlyContinue } else { $env:FAKE_HERMES_DISCOVERY_HOME = $PreviousFakeDiscoveryHome }
    # Elimina todo el fixture temporal y sus copias de skills/plugin.
    if (Test-Path $TempRoot) { Remove-Item -Recurse -Force -Path $TempRoot }
}
