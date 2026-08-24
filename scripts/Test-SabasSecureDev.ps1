# Declara un parámetro opcional para indicar una raíz distinta del bundle.
param(
    # Usa por defecto la carpeta padre de scripts.
    [string]$BundleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

# Activa comprobaciones estrictas.
Set-StrictMode -Version Latest
# Convierte errores en fallos terminantes.
$ErrorActionPreference = 'Stop'
# Selecciona Python 3.
$PythonCommand = if (Get-Command py -ErrorAction SilentlyContinue) { 'py' } elseif (Get-Command python -ErrorAction SilentlyContinue) { 'python' } else { $null }
# Exige Python.
if ([string]::IsNullOrWhiteSpace($PythonCommand)) { throw 'Python 3 is required to run the Sabas Secure Development self-test.' }
# Define el runner Python.
$TestScript = Join-Path $BundleRoot 'tests\test_sabas_secure_dev.py'
# Exige que el test exista.
if (-not (Test-Path $TestScript)) { throw "Missing self-test: $TestScript" }
# Ejecuta con py.exe cuando está disponible.
if ($PythonCommand -eq 'py') { & py -3 $TestScript --bundle $BundleRoot }
# Ejecuta con python directo en el resto de sistemas.
else { & python $TestScript --bundle $BundleRoot }
# Propaga fallo del test.
if ($LASTEXITCODE -ne 0) { throw 'Sabas Secure Development self-test failed.' }
# Confirma éxito.
Write-Host 'Sabas Secure Development self-test: PASS'
