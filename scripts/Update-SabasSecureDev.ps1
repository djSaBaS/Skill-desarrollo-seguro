# Declara el actualizador remoto de Sabas Secure Development.
param(
    # Selecciona el agente que se quiere actualizar; si se omite se delega el selector al setup descargado.
    [ValidateSet('Codex', 'Hermes', 'Antigravity', 'All')]
    [string]$Target,
    # Selecciona la rama o referencia pública que se descargará.
    [string]$Ref = 'main',
    # Solicita actualizar también las skills defensivas externas de Codex/Hermes.
    [switch]$InstallExternalSkills,
    # Selecciona el perfil defensivo externo.
    [ValidateSet('web', 'api', 'devsecops', 'all')]
    [string]$ExternalProfile = 'all',
    # Actualiza el bloque global AGENTS de Codex.
    [switch]$UpdateGlobalAgents,
    # Instala o refresca el Stop Hook de Codex.
    [switch]$InstallCompletionHook,
    # Permite reemplazos explícitos protegidos por el instalador.
    [switch]$Force
)

# Activa comprobaciones estrictas.
Set-StrictMode -Version Latest
# Convierte errores no terminantes en excepciones.
$ErrorActionPreference = 'Stop'
# Define el repositorio oficial que se usará como origen.
$Repository = 'djSaBaS/Skill-desarrollo-seguro'
# Crea una carpeta temporal aislada para la actualización.
$TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sabas-update-" + [Guid]::NewGuid().ToString('N'))
# Define el ZIP temporal descargado.
$ArchivePath = Join-Path $TempRoot 'bundle.zip'
# Crea la carpeta temporal antes de descargar.
New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null

# Garantiza limpieza temporal incluso cuando falle la actualización.
try {
    # Codifica la referencia para incorporarla de forma segura a la URL.
    $EscapedRef = [Uri]::EscapeDataString($Ref)
    # Construye la URL de archivo soportada por GitHub para ramas, tags y commits.
    $ArchiveUrl = "https://github.com/$Repository/archive/$EscapedRef.zip"
    # Informa del origen sin mostrar credenciales porque la actualización usa únicamente HTTPS público.
    Write-Host "Downloading Sabas bundle: $Repository@$Ref"
    # Descarga el bundle público.
    Invoke-WebRequest -Uri $ArchiveUrl -OutFile $ArchivePath -UseBasicParsing
    # Exige que la descarga haya creado un archivo no vacío.
    if ((-not (Test-Path $ArchivePath)) -or ((Get-Item $ArchivePath).Length -eq 0)) { throw 'Downloaded update archive is empty.' }
    # Expande el ZIP en la carpeta temporal.
    Expand-Archive -Path $ArchivePath -DestinationPath $TempRoot -Force
    # Localiza de forma determinista el setup dentro del único árbol extraído.
    $SetupCandidates = @(Get-ChildItem -Path $TempRoot -Filter 'Setup-SabasSecureDev.ps1' -File -Recurse)
    # Exige exactamente un entrypoint para evitar ejecutar un archivo ambiguo.
    if ($SetupCandidates.Count -ne 1) { throw "Expected exactly one Setup-SabasSecureDev.ps1, found $($SetupCandidates.Count)." }
    # Selecciona el setup validado por estructura.
    $SetupScript = $SetupCandidates[0].FullName
    # Prepara argumentos de actualización.
    $SetupArguments = @{
        # Fuerza el modo idempotente de actualización.
        Action = 'Update'
        # Transfiere el perfil externo.
        ExternalProfile = $ExternalProfile
    }
    # Transfiere el destino únicamente cuando fue indicado.
    if (-not [string]::IsNullOrWhiteSpace($Target)) { $SetupArguments['Target'] = $Target }
    # Transfiere la solicitud de skills externas.
    if ($InstallExternalSkills) { $SetupArguments['InstallExternalSkills'] = $true }
    # Transfiere la actualización de instrucciones globales.
    if ($UpdateGlobalAgents) { $SetupArguments['UpdateGlobalAgents'] = $true }
    # Transfiere la instalación del hook.
    if ($InstallCompletionHook) { $SetupArguments['InstallCompletionHook'] = $true }
    # Transfiere Force únicamente cuando se solicitó.
    if ($Force) { $SetupArguments['Force'] = $true }
    # Ejecuta el setup descargado; este valida MANIFEST y autopruebas antes de copiar componentes.
    & $SetupScript @SetupArguments
    # Detiene si la actualización devolvió un fallo.
    if (-not $?) { throw 'Sabas update failed.' }
}
finally {
    # Elimina siempre la carpeta temporal para no dejar copias del bundle.
    if (Test-Path $TempRoot) { Remove-Item -Recurse -Force -Path $TempRoot }
}
