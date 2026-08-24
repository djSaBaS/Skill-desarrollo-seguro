# Declara opciones conservadoras para retirar Sabas Secure Development de Codex, Hermes o ambos.
param(
    # Selecciona el agente; si se omite se muestra un menú.
    [ValidateSet('Codex', 'Hermes', 'Both')]
    [string]$Target,
    # Permite retirar el bloque administrado de AGENTS.md/AGENTS.override.md de Codex.
    [switch]$RemoveGlobalAgentsBlock,
    # Permite retirar el Stop Hook administrado de Codex.
    [switch]$RemoveCompletionHook,
    # Permite retirar usuario-torpe-qa únicamente cuando conserva el marcador de copia instalada por este bundle.
    [switch]$RemoveBundledUsuarioTorpe
)

# Activa modo estricto.
Set-StrictMode -Version Latest
# Convierte errores no terminantes en excepciones.
$ErrorActionPreference = 'Stop'
# Respeta CODEX_HOME personalizado.
$CodexHome = if ([string]::IsNullOrWhiteSpace($env:CODEX_HOME)) { Join-Path $HOME '.codex' } else { $env:CODEX_HOME }
# Respeta HERMES_HOME personalizado.
$HermesHome = if ([string]::IsNullOrWhiteSpace($env:HERMES_HOME)) { Join-Path $HOME '.hermes' } else { $env:HERMES_HOME }
# Define los árboles de skills.
$CodexSkillsTarget = Join-Path $HOME '.agents\skills'
# Define el árbol nativo de Hermes.
$HermesSkillsTarget = Join-Path $HermesHome 'skills'
# Genera una marca temporal.
$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
# Define una carpeta neutral de backup.
$BackupRoot = Join-Path $HOME ".sabas-secure-development\backups\uninstall-$Timestamp"
# Crea el backup antes de borrar componentes.
New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null
# Define únicamente las skills propias del producto.
$SkillNames = @('sabas-secure-qa', 'sabas-threat-model', 'sabas-security-bootstrap')

# Solicita destino si no se indicó por parámetro.
if ([string]::IsNullOrWhiteSpace($Target)) {
    # Muestra opciones.
    Write-Host 'Selecciona de dónde retirar Sabas Secure Development:'
    # Opción Codex.
    Write-Host '  1) Codex'
    # Opción Hermes.
    Write-Host '  2) Hermes'
    # Opción ambos.
    Write-Host '  3) Codex + Hermes'
    # Lee elección.
    $Choice = Read-Host 'Opción [1-3]'
    # Normaliza elección.
    switch ($Choice) {
        # Selecciona Codex.
        '1' { $Target = 'Codex' }
        # Selecciona Hermes.
        '2' { $Target = 'Hermes' }
        # Selecciona ambos.
        '3' { $Target = 'Both' }
        # Rechaza valor inválido.
        default { throw 'Invalid target selection.' }
    }
}

# Elimina skills propias de un árbol conservando backup.
function Remove-SabasOwnedSkills {
    # Declara parámetros.
    param(
        # Recibe directorio de skills.
        [Parameter(Mandatory = $true)][string]$SkillsTarget,
        # Recibe etiqueta de plataforma.
        [Parameter(Mandatory = $true)][string]$PlatformName
    )
    # Crea backup específico de plataforma.
    $PlatformBackup = Join-Path $BackupRoot $PlatformName
    # Crea su directorio.
    New-Item -ItemType Directory -Force -Path $PlatformBackup | Out-Null
    # Recorre skills propias.
    foreach ($SkillName in $SkillNames) {
        # Construye ruta instalada.
        $InstalledSkill = Join-Path $SkillsTarget $SkillName
        # Actúa solo si existe.
        if (Test-Path $InstalledSkill) {
            # Conserva copia completa.
            Copy-Item -Recurse -Force -Path $InstalledSkill -Destination (Join-Path $PlatformBackup $SkillName)
            # Elimina únicamente la skill propia.
            Remove-Item -Recurse -Force -Path $InstalledSkill
            # Informa de la retirada.
            Write-Host "Removed [$PlatformName]: $SkillName"
        }
    }
}

# Retira usuario-torpe-qa solo cuando el marcador demuestra que la copia completa fue instalada por Sabas.
function Remove-SabasBundledTorpe {
    # Declara parámetros.
    param(
        # Recibe árbol de skills.
        [Parameter(Mandatory = $true)][string]$SkillsTarget,
        # Recibe etiqueta.
        [Parameter(Mandatory = $true)][string]$PlatformName
    )
    # Define la carpeta de la skill.
    $TorpeTarget = Join-Path $SkillsTarget 'usuario-torpe-qa'
    # Define el marcador de propiedad del bundle.
    $TorpeMarker = Join-Path $TorpeTarget '.sabas-bundled-support.json'
    # Elimina únicamente cuando existe el marcador.
    if ((Test-Path $TorpeTarget) -and (Test-Path $TorpeMarker)) {
        # Conserva backup.
        Copy-Item -Recurse -Force -Path $TorpeTarget -Destination (Join-Path $BackupRoot "usuario-torpe-qa-$PlatformName")
        # Elimina la copia completa.
        Remove-Item -Recurse -Force -Path $TorpeTarget
        # Informa de la retirada.
        Write-Host "Removed bundled usuario-torpe-qa [$PlatformName]"
    }
    elseif (Test-Path $TorpeTarget) {
        # Preserva una versión propia o de procedencia no demostrable.
        Write-Warning "usuario-torpe-qa preserved [$PlatformName]: no Sabas bundled-support marker was found."
    }
}

# Elimina únicamente el bloque Sabas de un archivo AGENTS.
function Remove-SabasAgentsBlock {
    # Recibe ruta de instrucciones.
    param([Parameter(Mandatory = $true)][string]$AgentsFile)
    # Sale si no existe.
    if (-not (Test-Path $AgentsFile)) { return }
    # Lee el contenido existente.
    $Existing = Get-Content -Raw -Path $AgentsFile
    # Sale si no contiene el bloque administrado.
    if ($Existing -notmatch 'SABAS-SECURE-DEVELOPMENT:START') { return }
    # Conserva backup.
    Copy-Item -Force -Path $AgentsFile -Destination (Join-Path $BackupRoot ((Split-Path -Leaf $AgentsFile) + '.bak'))
    # Define el patrón delimitado.
    $ManagedBlockPattern = '(?s)\s*<!-- SABAS-SECURE-DEVELOPMENT:START -->.*?<!-- SABAS-SECURE-DEVELOPMENT:END -->\s*'
    # Elimina únicamente el bloque administrado.
    $Updated = [Regex]::Replace($Existing, $ManagedBlockPattern, "`r`n`r`n").Trim()
    # Conserva nueva línea final cuando quedan instrucciones.
    $FinalContent = if ([string]::IsNullOrWhiteSpace($Updated)) { '' } else { $Updated + "`r`n" }
    # Guarda el resultado.
    Set-Content -Path $AgentsFile -Value $FinalContent -Encoding utf8
    # Informa de la retirada.
    Write-Host "Removed Sabas security block: $AgentsFile"
}

# Convierte objetos JSON en hashtables compatibles con Windows PowerShell 5.1.
function ConvertTo-SabasHashtable {
    # Recibe nodo JSON.
    param([Parameter(ValueFromPipeline = $true)]$InputObject)
    # Conserva null.
    if ($null -eq $InputObject) { return $null }
    # Convierte PSCustomObject.
    if ($InputObject -is [System.Management.Automation.PSCustomObject]) {
        # Inicializa mapa.
        $Result = @{}
        # Recorre propiedades.
        foreach ($Property in $InputObject.PSObject.Properties) { $Result[$Property.Name] = ConvertTo-SabasHashtable -InputObject $Property.Value }
        # Devuelve mapa.
        return $Result
    }
    # Convierte colecciones no string.
    if (($InputObject -is [System.Collections.IEnumerable]) -and -not ($InputObject -is [string]) -and -not ($InputObject -is [System.Collections.IDictionary])) {
        # Inicializa array.
        $Items = @()
        # Convierte cada elemento.
        foreach ($Item in $InputObject) { $Items += ,(ConvertTo-SabasHashtable -InputObject $Item) }
        # Devuelve array.
        return $Items
    }
    # Conserva escalares y diccionarios.
    return $InputObject
}

# Retira el Stop Hook de Codex conservando hooks ajenos.
function Remove-SabasCodexHook {
    # Define hooks.json.
    $HooksFile = Join-Path $CodexHome 'hooks.json'
    # Modifica solo si existe.
    if (Test-Path $HooksFile) {
        # Conserva backup.
        Copy-Item -Force -Path $HooksFile -Destination (Join-Path $BackupRoot 'codex-hooks.json.bak')
        # Lee JSON.
        $RawHooks = Get-Content -Raw -Path $HooksFile
        # Parsea o crea objeto vacío.
        $ParsedHooks = if ([string]::IsNullOrWhiteSpace($RawHooks)) { @{} } else { $RawHooks | ConvertFrom-Json }
        # Normaliza.
        $HooksConfig = ConvertTo-SabasHashtable -InputObject $ParsedHooks
        # Rechaza raíz incompatible.
        if (-not ($HooksConfig -is [System.Collections.IDictionary])) { throw 'Codex hooks.json root is not an object.' }
        # Procesa sección hooks cuando existe.
        if ($HooksConfig.ContainsKey('hooks') -and ($HooksConfig['hooks'] -is [System.Collections.IDictionary])) {
            # Obtiene eventos.
            $Events = $HooksConfig['hooks']
            # Procesa Stop.
            if ($Events.ContainsKey('Stop')) {
                # Conserva entradas ajenas.
                $FilteredEntries = @(@($Events['Stop']) | Where-Object { (($_ | ConvertTo-Json -Depth 20) -notmatch 'sabas_secure_stop\.py') })
                # Conserva Stop si quedan entradas.
                if ($FilteredEntries.Count -gt 0) { $Events['Stop'] = $FilteredEntries }
                # Elimina la clave si quedó vacía.
                else { $Events.Remove('Stop') }
            }
        }
        # Escribe la configuración preservada.
        Set-Content -Path $HooksFile -Value ($HooksConfig | ConvertTo-Json -Depth 20) -Encoding utf8
        # Informa.
        Write-Host "Removed Sabas Stop hook entry: $HooksFile"
    }
    # Define el script runtime.
    $HookScript = Join-Path $CodexHome 'hooks\sabas_secure_stop.py'
    # Retira el script si existe.
    if (Test-Path $HookScript) {
        # Conserva backup.
        Copy-Item -Force -Path $HookScript -Destination (Join-Path $BackupRoot 'codex-sabas_secure_stop.py.bak')
        # Elimina el script.
        Remove-Item -Force -Path $HookScript
        # Informa.
        Write-Host "Removed Sabas hook script: $HookScript"
    }
}

# Retira el plugin Hermes administrado por Sabas.
function Remove-SabasHermesPlugin {
    # Define la ruta instalada.
    $PluginTarget = Join-Path $HermesHome 'plugins\sabas-secure-development'
    # Deshabilita el plugin mediante la CLI cuando está disponible.
    if (Get-Command hermes -ErrorAction SilentlyContinue) {
        # Conserva la política estricta porque PowerShell 5.1 puede promover stderr nativo a error.
        $PreviousHermesDisableErrorActionPreference = $ErrorActionPreference
        # Garantiza la restauración tras la llamada.
        try {
            # Evita que un mensaje informativo de Hermes interrumpa la desinstalación.
            $ErrorActionPreference = 'Continue'
            # Solicita deshabilitado explícito y descarta su salida.
            @(& hermes plugins disable sabas-secure-development 2>&1) | Out-Null
            # Conserva el exit code real.
            $HermesDisableExitCode = $LASTEXITCODE
        }
        finally {
            # Restaura la política original.
            $ErrorActionPreference = $PreviousHermesDisableErrorActionPreference
        }
        # No falla la desinstalación por una CLI antigua; se seguirá retirando el código local.
        if ($HermesDisableExitCode -ne 0) { Write-Warning 'Hermes could not disable the plugin through CLI; removing the plugin directory anyway.' }
    }
    # Retira la carpeta cuando existe.
    if (Test-Path $PluginTarget) {
        # Conserva copia.
        Copy-Item -Recurse -Force -Path $PluginTarget -Destination (Join-Path $BackupRoot 'hermes-plugin-sabas-secure-development')
        # Elimina el plugin administrado.
        Remove-Item -Recurse -Force -Path $PluginTarget
        # Informa.
        Write-Host "Removed Hermes plugin: $PluginTarget"
    }
    # Aclara la política conservadora sobre configuración global de Hermes.
    Write-Host 'Hermes verify_on_stop/coding settings were left unchanged to avoid overwriting user configuration.'
}

# Retira Codex cuando está seleccionado.
if (($Target -eq 'Codex') -or ($Target -eq 'Both')) {
    # Elimina skills propias.
    Remove-SabasOwnedSkills -SkillsTarget $CodexSkillsTarget -PlatformName 'Codex'
    # Retira bloque global solo si se pidió.
    if ($RemoveGlobalAgentsBlock) {
        # Procesa AGENTS principal.
        Remove-SabasAgentsBlock -AgentsFile (Join-Path $CodexHome 'AGENTS.md')
        # Procesa override.
        Remove-SabasAgentsBlock -AgentsFile (Join-Path $CodexHome 'AGENTS.override.md')
    }
    # Retira hook solo si se pidió.
    if ($RemoveCompletionHook) { Remove-SabasCodexHook }
    # Retira torpe únicamente con autorización y marcador.
    if ($RemoveBundledUsuarioTorpe) { Remove-SabasBundledTorpe -SkillsTarget $CodexSkillsTarget -PlatformName 'Codex' }
}

# Retira Hermes cuando está seleccionado.
if (($Target -eq 'Hermes') -or ($Target -eq 'Both')) {
    # Elimina skills propias.
    Remove-SabasOwnedSkills -SkillsTarget $HermesSkillsTarget -PlatformName 'Hermes'
    # Retira el plugin propio.
    Remove-SabasHermesPlugin
    # Retira torpe únicamente con autorización y marcador.
    if ($RemoveBundledUsuarioTorpe) { Remove-SabasBundledTorpe -SkillsTarget $HermesSkillsTarget -PlatformName 'Hermes' }
}

# Aclara que las skills externas se preservan porque pueden usarse de forma independiente.
Write-Host 'External cybersecurity skills are intentionally left installed.'
# Informa de backups.
Write-Host "Backup directory: $BackupRoot"
# Confirma finalización.
Write-Host "Sabas Secure Development removed for target: $Target"
