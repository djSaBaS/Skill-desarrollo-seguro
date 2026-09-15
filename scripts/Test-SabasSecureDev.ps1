# Declara un parametro opcional para indicar una raiz distinta del bundle.
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
# Define el runner principal Python.
$TestScript = Join-Path $BundleRoot 'tests\test_sabas_secure_dev.py'
# Define el test portable adicional.
$PortableTestScript = Join-Path $BundleRoot 'tests\test_portable_setup.py'
# Exige que el test principal exista.
if (-not (Test-Path $TestScript)) { throw "Missing self-test: $TestScript" }
# Exige que el test portable exista.
if (-not (Test-Path $PortableTestScript)) { throw "Missing portable self-test: $PortableTestScript" }
# Ejecuta el test principal con py.exe cuando esta disponible.
if ($PythonCommand -eq 'py') { & py -3 $TestScript --bundle $BundleRoot }
# Ejecuta el test principal con python directo en el resto de sistemas.
else { & python $TestScript --bundle $BundleRoot }
# Propaga fallo del test principal.
if ($LASTEXITCODE -ne 0) { throw 'Sabas Secure Development core self-test failed.' }
# Ejecuta el test portable con py.exe cuando esta disponible.
if ($PythonCommand -eq 'py') { & py -3 $PortableTestScript $BundleRoot }
# Ejecuta el test portable con python directo en el resto de sistemas.
else { & python $PortableTestScript $BundleRoot }
# Propaga fallo del test portable.
if ($LASTEXITCODE -ne 0) { throw 'Sabas Secure Development portable self-test failed.' }
# Confirma exito.
Write-Host 'Sabas Secure Development self-test: PASS'
