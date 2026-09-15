# Declara un parametro opcional para indicar una raiz distinta del bundle.
param(
    # Usa por defecto la carpeta padre de scripts.
    [string]$BundleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

# Activa comprobaciones estrictas.
Set-StrictMode -Version Latest
# Convierte errores en fallos terminantes.
$ErrorActionPreference = 'Stop'
# Resuelve la raiz fuente antes de crear la copia de validacion.
$SourceRoot = (Resolve-Path $BundleRoot).Path
# Selecciona Python 3.
$PythonCommand = if (Get-Command py -ErrorAction SilentlyContinue) { 'py' } elseif (Get-Command python -ErrorAction SilentlyContinue) { 'python' } else { $null }
# Exige Python.
if ([string]::IsNullOrWhiteSpace($PythonCommand)) { throw 'Python 3 is required to run the Sabas Secure Development self-test.' }
# Crea una raiz temporal independiente para validar exactamente el bundle distribuible sin metadatos de Git.
$ValidationRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('sabas-self-test-' + [Guid]::NewGuid().ToString('N'))

# Copia el bundle conservando archivos ocultos pero excluyendo exclusivamente los metadatos internos de Git.
function Copy-SabasValidationBundle {
    # Crea la carpeta temporal vacia.
    New-Item -ItemType Directory -Force -Path $ValidationRoot | Out-Null
    # Enumera tambien archivos y directorios ocultos del bundle.
    $BundleEntries = @(Get-ChildItem -LiteralPath $SourceRoot -Force)
    # Recorre cada entrada de primer nivel.
    foreach ($BundleEntry in $BundleEntries) {
        # Excluye .git porque MANIFEST.sha256 describe el artefacto distribuible, no la base de datos local de Git.
        if ($BundleEntry.Name -eq '.git') { continue }
        # Copia cada entrada sin reinterpretar su contenido ni su codificacion.
        Copy-Item -LiteralPath $BundleEntry.FullName -Destination $ValidationRoot -Recurse -Force
    }
}

# Garantiza limpieza de la copia temporal tanto en PASS como en FAIL.
try {
    # Prepara una copia reproducible del bundle para la validacion.
    Copy-SabasValidationBundle
    # Define el runner principal Python dentro de la copia distribuible.
    $TestScript = Join-Path $ValidationRoot 'tests\test_sabas_secure_dev.py'
    # Define el test portable adicional dentro de la copia distribuible.
    $PortableTestScript = Join-Path $ValidationRoot 'tests\test_portable_setup.py'
    # Exige que el test principal exista.
    if (-not (Test-Path $TestScript)) { throw "Missing self-test: $TestScript" }
    # Exige que el test portable exista.
    if (-not (Test-Path $PortableTestScript)) { throw "Missing portable self-test: $PortableTestScript" }
    # Ejecuta el test principal con py.exe cuando esta disponible.
    if ($PythonCommand -eq 'py') { & py -3 $TestScript --bundle $ValidationRoot }
    # Ejecuta el test principal con python directo en el resto de sistemas.
    else { & python $TestScript --bundle $ValidationRoot }
    # Propaga fallo del test principal.
    if ($LASTEXITCODE -ne 0) { throw 'Sabas Secure Development core self-test failed.' }
    # Ejecuta el test portable con py.exe cuando esta disponible.
    if ($PythonCommand -eq 'py') { & py -3 $PortableTestScript $ValidationRoot }
    # Ejecuta el test portable con python directo en el resto de sistemas.
    else { & python $PortableTestScript $ValidationRoot }
    # Propaga fallo del test portable.
    if ($LASTEXITCODE -ne 0) { throw 'Sabas Secure Development portable self-test failed.' }
    # Confirma exito.
    Write-Host 'Sabas Secure Development self-test: PASS'
}
finally {
    # Elimina siempre la copia temporal para no dejar residuos tras la autoprueba.
    if (Test-Path $ValidationRoot) { Remove-Item -Recurse -Force -Path $ValidationRoot }
}
