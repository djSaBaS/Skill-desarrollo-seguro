# Declara la raíz del bundle como parámetro opcional para CI y ejecución manual.
param(
    # Usa el padre de tests por defecto.
    [string]$BundleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

# Activa comprobaciones estrictas para que el smoke test no oculte errores.
Set-StrictMode -Version Latest
# Convierte errores PowerShell en fallos terminantes.
$ErrorActionPreference = 'Stop'

# Exige Windows porque el objetivo de esta prueba es reproducir Windows PowerShell/paths nativos.
if ($env:OS -ne 'Windows_NT') {
    # Informa del skip deliberado en otros sistemas.
    Write-Host 'HERMES_INSTALLER_SMOKE: SKIP (Windows only)'
    # Devuelve éxito porque Linux tiene su propia validación de bundle.
    exit 0
}

# Crea una raíz temporal aislada para no tocar la instalación Hermes real.
$TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('sabas-hermes-installer-smoke-' + [System.Guid]::NewGuid().ToString('N'))
# Define un HERMES_HOME temporal.
$FakeHermesHome = Join-Path $TempRoot 'hermes-home'
# Define un directorio temporal para la CLI falsa.
$FakeBin = Join-Path $TempRoot 'bin'
# Define backups temporales.
$FakeBackups = Join-Path $TempRoot 'backups'
# Crea las carpetas del fixture.
New-Item -ItemType Directory -Force -Path $FakeHermesHome, $FakeBin, $FakeBackups | Out-Null

# Conserva variables de entorno que se modificarán durante el fixture.
$PreviousPath = $env:PATH
# Conserva HERMES_HOME real.
$PreviousHermesHome = $env:HERMES_HOME
# Conserva el override de backups real.
$PreviousBackupRoot = $env:SABAS_SECURE_BACKUP_ROOT

# Garantiza limpieza y restauración aunque el instalador falle.
try {
    # Define el backend Python de una CLI Hermes mínima y determinista.
    $FakeHermesPython = Join-Path $FakeBin 'fake_hermes.py'
    # Escribe la CLI falsa en UTF-8.
    @'
import os
import sys
from pathlib import Path

home = Path(os.environ["HERMES_HOME"])
args = sys.argv[1:]
plugin = home / "plugins" / "sabas-secure-development"

if args == ["--version"]:
    print("[plugins] diagnostic warning on stderr must not abort PowerShell 5.1", file=sys.stderr)
    print("hermes 0.test")
    raise SystemExit(0)
if args == ["config", "path"]:
    print(home / "config.yaml")
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
if args == ["plugins", "enable", "security-guidance"]:
    print("security-guidance not installed", file=sys.stderr)
    raise SystemExit(2)
if args == ["plugins", "list", "--plain", "--no-bundled"]:
    # Simula la vista compacta estable que Hermes real recomienda para automatización.
    if (plugin / "plugin.yaml").is_file():
        print("sabas-secure-development enabled 0.5.4 user")
    raise SystemExit(0)
if args == ["plugins", "list"]:
    if os.environ.get("HERMES_PLUGINS_DEBUG") == "1":
        print("[plugins] DEBUG HERMES_PLUGINS_DEBUG=1 — verbose plugin discovery logging enabled", file=sys.stderr)
        print(f"[plugins] scanning: {home / 'plugins'}", file=sys.stderr)
    print(f"scan user plugins: {home / 'plugins'}")
    if (plugin / "plugin.yaml").is_file():
        # Reproduce exactamente la regresión real: Rich trunca el nombre por ancho de consola.
        print("sabas-secure-devel… enabled 0.5.4 Security guardrails user")
    raise SystemExit(0)
if len(args) >= 4 and args[:2] == ["config", "set"]:
    print("configured")
    raise SystemExit(0)
print("unsupported fake Hermes command: " + " ".join(args), file=sys.stderr)
raise SystemExit(2)
'@ | Set-Content -Path $FakeHermesPython -Encoding utf8
    # Define un wrapper .cmd para que Get-Command hermes funcione como en una instalación real de Windows.
    $FakeHermesCmd = Join-Path $FakeBin 'hermes.cmd'
    # Escribe el wrapper usando py -3 cuando existe y python como fallback.
    if (Get-Command py -ErrorAction SilentlyContinue) {
        # Usa el launcher estándar de Windows.
        '@echo off' + "`r`n" + 'py -3 "%~dp0fake_hermes.py" %*' | Set-Content -Path $FakeHermesCmd -Encoding ascii
    }
    else {
        # Usa python directo en runners sin py.exe.
        '@echo off' + "`r`n" + 'python "%~dp0fake_hermes.py" %*' | Set-Content -Path $FakeHermesCmd -Encoding ascii
    }
    # Aísla Hermes en el fixture temporal.
    $env:HERMES_HOME = $FakeHermesHome
    # Aísla también los backups del instalador.
    $env:SABAS_SECURE_BACKUP_ROOT = $FakeBackups
    # Coloca primero la CLI falsa sin ocultar herramientas del sistema.
    $env:PATH = $FakeBin + [System.IO.Path]::PathSeparator + $PreviousPath
    # Define el instalador real que se quiere probar.
    $Installer = Join-Path $BundleRoot 'scripts\Install-SabasSecureDev.ps1'
    # Ejecuta una instalación Hermes real contra el fixture, sin red ni skills externas.
    & $Installer -Target Hermes
    # Exige que la skill principal haya terminado en el mismo home confirmado.
    if (-not (Test-Path (Join-Path $FakeHermesHome 'skills\sabas-secure-qa\SKILL.md'))) { throw 'Smoke test: sabas-secure-qa was not installed.' }
    # Exige que usuario-torpe-qa esté presente.
    if (-not (Test-Path (Join-Path $FakeHermesHome 'skills\usuario-torpe-qa\SKILL.md'))) { throw 'Smoke test: usuario-torpe-qa was not installed.' }
    # Exige el manifiesto del plugin.
    if (-not (Test-Path (Join-Path $FakeHermesHome 'plugins\sabas-secure-development\plugin.yaml'))) { throw 'Smoke test: Hermes plugin manifest was not installed.' }
    # Exige el código del plugin.
    if (-not (Test-Path (Join-Path $FakeHermesHome 'plugins\sabas-secure-development\__init__.py'))) { throw 'Smoke test: Hermes plugin code was not installed.' }
    # Exige el marcador de propiedad que permite limpiezas futuras sin borrar plugins ajenos.
    if (-not (Test-Path (Join-Path $FakeHermesHome 'plugins\sabas-secure-development\.sabas-managed-plugin.json'))) { throw 'Smoke test: Hermes plugin ownership marker was not installed.' }
    # Emite un marcador inequívoco de éxito para CI.
    Write-Host 'HERMES_INSTALLER_SMOKE: PASS'
}
finally {
    # Restaura PATH incluso si el test falla.
    $env:PATH = $PreviousPath
    # Restaura o elimina HERMES_HOME según su estado previo.
    if ($null -eq $PreviousHermesHome) { Remove-Item Env:HERMES_HOME -ErrorAction SilentlyContinue } else { $env:HERMES_HOME = $PreviousHermesHome }
    # Restaura o elimina el override de backups.
    if ($null -eq $PreviousBackupRoot) { Remove-Item Env:SABAS_SECURE_BACKUP_ROOT -ErrorAction SilentlyContinue } else { $env:SABAS_SECURE_BACKUP_ROOT = $PreviousBackupRoot }
    # Elimina todo el fixture temporal y sus copias de skills/plugin.
    if (Test-Path $TempRoot) { Remove-Item -Recurse -Force -Path $TempRoot }
}
