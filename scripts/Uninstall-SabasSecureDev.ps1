# Declara opciones conservadoras para retirar Sabas Secure Development de los agentes soportados.
param(
    # Selecciona el agente; si se omite se muestra un menú.
    [ValidateSet('Codex', 'Hermes', 'Antigravity', 'Both', 'All')]
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
# Define el árbol estándar de skills de Codex.
$CodexSkillsTarget = Join-Path $HOME '.agents\skills'
# Define el árbol global oficial de Google Antigravity IDE.
$AntigravitySkillsTarget = Join-Path $HOME '.gemini\config\skills'
# Inicializa el home Hermes para resolverlo solo cuando ese destino se vaya a retirar.
$HermesHome = $null
# Inicializa el árbol de skills Hermes para calcularlo a partir del home efectivo.
$HermesSkillsTarget = $null
# Genera una marca temporal.
$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
# Define una carpeta neutral de backup.
$BackupRoot = Join-Path $HOME ".sabas-secure-development\backups\uninstall-$Timestamp"
# Crea el backup antes de borrar componentes.
New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null
# Define todas las skills propias instaladas por el bundle portable.
$SkillNames = @('sabas-efficient-development', 'sabas-secure-qa', 'sabas-threat-model', 'sabas-security-bootstrap')

# Solicita destino si no se indicó por parámetro.
if ([string]::IsNullOrWhiteSpace($Target)) {
    # Muestra opciones.
    Write-Host 'Selecciona de dónde retirar Sabas Secure Development:'
    # Opción Codex.
    Write-Host '  1) Codex'
    # Opción Hermes.
    Write-Host '  2) Hermes'
    # Opción Antigravity.
    Write-Host '  3) Google Antigravity IDE'
    # Opción todos los destinos.
    Write-Host '  4) Todos'
    # Lee elección.
    $Choice = Read-Host 'Opción [1-4]'
    # Normaliza elección.
    switch ($Choice) {
        # Selecciona Codex.
        '1' { $Target = 'Codex' }
        # Selecciona Hermes.
        '2' { $Target = 'Hermes' }
        # Selecciona Antigravity.
        '3' { $Target = 'Antigravity' }
        # Selecciona todos.
        '4' { $Target = 'All' }
        # Rechaza valor inválido.
        default { throw 'Invalid target selection.' }
    }
}

# Resuelve el home de Hermes reproduciendo el orden de evidencia del instalador principal.
function Resolve-SabasHermesHome {
    # Inicializa candidatos ordenados por confianza teórica.
    $Candidates = New-Object System.Collections.Generic.List[object]
    # Define un helper local para añadir homes sin duplicados.
    function Add-SabasHermesHomeCandidate {
        # Recibe ruta y procedencia.
        param([string]$Path, [string]$Source)
        # Ignora rutas vacías.
        if ([string]::IsNullOrWhiteSpace($Path)) { return }
        # Normaliza separadores finales sin resolver rutas que todavía pueden no existir.
        $NormalizedPath = ([string]$Path).TrimEnd([char]92, [char]47)
        # Evita duplicados ignorando mayúsculas/minúsculas.
        foreach ($Existing in $Candidates) {
            # Sale cuando el candidato ya estaba registrado.
            if ([string]::Equals([string]$Existing.Path, $NormalizedPath, [System.StringComparison]::OrdinalIgnoreCase)) { return }
        }
        # Añade ruta y fuente de evidencia.
        $Candidates.Add([PSCustomObject]@{ Path = $NormalizedPath; Source = $Source })
    }
    # Detecta si la CLI Hermes está disponible.
    $HermesAvailable = $null -ne (Get-Command hermes -ErrorAction SilentlyContinue)
    # Consulta primero el perfil declarado por la CLI cuando está disponible.
    if ($HermesAvailable) {
        # Conserva la política de errores actual.
        $PreviousErrorActionPreference = $ErrorActionPreference
        # Captura config path tolerando stderr informativo de Windows PowerShell 5.1.
        try {
            # Trata stderr como datos durante la llamada nativa.
            $ErrorActionPreference = 'Continue'
            # Captura la salida completa.
            $ConfigOutput = @(& hermes config path 2>&1)
            # Conserva el código de salida real.
            $ConfigExitCode = $LASTEXITCODE
        }
        finally {
            # Restaura la política de errores previa.
            $ErrorActionPreference = $PreviousErrorActionPreference
        }
        # Procesa únicamente una respuesta correcta.
        if ($ConfigExitCode -eq 0) {
            # Recorre todas las líneas recibidas.
            foreach ($Line in $ConfigOutput) {
                # Limpia espacios exteriores.
                $Text = ([string]$Line).Trim()
                # Detecta una ruta de configuración Windows o POSIX.
                if ($Text -match '(?i)([A-Z]:[\\/].*config\.ya?ml|/.*config\.ya?ml)\s*$') {
                    # Añade como primer candidato el home declarado por Hermes.
                    Add-SabasHermesHomeCandidate -Path (Split-Path -Parent $Matches[1]) -Source 'hermes config path'
                    # Basta una ruta de configuración válida.
                    break
                }
            }
        }
    }
    # Añade HERMES_HOME como fallback explícito.
    Add-SabasHermesHomeCandidate -Path $env:HERMES_HOME -Source 'HERMES_HOME environment variable'
    # Añade el layout Windows moderno cuando corresponde.
    if (($env:OS -eq 'Windows_NT') -and (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA))) {
        # Registra el home moderno de Windows.
        Add-SabasHermesHomeCandidate -Path (Join-Path $env:LOCALAPPDATA 'hermes') -Source 'Windows LOCALAPPDATA default'
    }
    # Añade el layout histórico/portable como último fallback.
    Add-SabasHermesHomeCandidate -Path (Join-Path $HOME '.hermes') -Source 'legacy/POSIX ~/.hermes fallback'
    # Exige al menos un candidato razonable.
    if ($Candidates.Count -eq 0) { throw 'Unable to resolve any Hermes home candidate.' }
    # Deja que discovery real gane frente a config path o variables stale.
    if ($HermesAvailable) {
        # Conserva el valor previo de debug.
        $PreviousPluginsDebug = $env:HERMES_PLUGINS_DEBUG
        # Conserva la política de errores previa.
        $PreviousDiscoveryErrorActionPreference = $ErrorActionPreference
        # Ejecuta discovery de forma tolerante.
        try {
            # Evita que stderr informativo se convierta en excepción.
            $ErrorActionPreference = 'Continue'
            # Activa el diagnóstico oficial de rutas de plugin.
            $env:HERMES_PLUGINS_DEBUG = '1'
            # Captura la salida de discovery.
            $DiscoveryOutput = @(& hermes plugins list 2>&1)
            # Conserva el exit code real.
            $DiscoveryExitCode = $LASTEXITCODE
        }
        finally {
            # Restaura la política de errores.
            $ErrorActionPreference = $PreviousDiscoveryErrorActionPreference
            # Restaura exactamente el valor previo de debug.
            if ($null -eq $PreviousPluginsDebug) { Remove-Item Env:HERMES_PLUGINS_DEBUG -ErrorAction SilentlyContinue }
            else { $env:HERMES_PLUGINS_DEBUG = $PreviousPluginsDebug }
        }
        # Procesa discovery únicamente cuando la CLI terminó correctamente.
        if ($DiscoveryExitCode -eq 0) {
            # Une líneas, elimina ANSI y normaliza separadores/case para comparar rutas.
            $DiscoveryText = (((@($DiscoveryOutput) | ForEach-Object { ([string]$_) -replace '\x1B\[[0-?]*[ -/]*[@-~]', '' }) -join [Environment]::NewLine).Replace([char]92, [char]47)).ToLowerInvariant()
            # Recorre candidatos en orden.
            foreach ($Candidate in $Candidates) {
                # Normaliza la ruta de plugins que correspondería a ese home.
                $CandidatePlugins = (([string]$Candidate.Path).Replace([char]92, [char]47).TrimEnd('/') + '/plugins').ToLowerInvariant()
                # Devuelve el home que Hermes confirma que está escaneando realmente.
                if ($DiscoveryText.Contains($CandidatePlugins)) { return [string]$Candidate.Path }
            }
        }
    }
    # Prefiere un candidato donde exista una instalación Sabas demostrable cuando discovery no decidió.
    foreach ($Candidate in $Candidates) {
        # Define señales de instalación propias.
        $HasSkill = Test-Path (Join-Path ([string]$Candidate.Path) 'skills\sabas-secure-qa\SKILL.md')
        # Define el marcador propio del plugin Hermes.
        $HasManagedPlugin = Test-Path (Join-Path ([string]$Candidate.Path) 'plugins\sabas-secure-development\.sabas-managed-plugin.json')
        # Usa el primer home con evidencia Sabas.
        if ($HasSkill -or $HasManagedPlugin) { return [string]$Candidate.Path }
    }
    # Devuelve el candidato teórico de mayor confianza como último fallback.
    return [string]$Candidates[0].Path
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

# Lee un archivo UTF-8 de forma explícita para no depender de la página ANSI de Windows PowerShell 5.1.
function Read-SabasUtf8Text {
    # Recibe la ruta que debe decodificarse.
    param([Parameter(Mandatory = $true)][string]$Path)
    # Lee los bytes sin aplicar ninguna codificación implícita.
    $SourceBytes = [System.IO.File]::ReadAllBytes($Path)
    # Detecta una firma UTF-8 BOM opcional.
    $HasUtf8Bom = ($SourceBytes.Length -ge 3) -and ($SourceBytes[0] -eq 0xEF) -and ($SourceBytes[1] -eq 0xBB) -and ($SourceBytes[2] -eq 0xBF)
    # Omite solamente la firma BOM cuando existe.
    $Utf8Offset = if ($HasUtf8Bom) { 3 } else { 0 }
    # Calcula los bytes reales de contenido.
    $Utf8Count = $SourceBytes.Length - $Utf8Offset
    # Crea un decodificador UTF-8 estricto para detectar corrupción en vez de ocultarla.
    $Utf8Strict = New-Object System.Text.UTF8Encoding($false, $true)
    # Decodifica explícitamente y transforma bytes inválidos en un error controlado.
    try { return $Utf8Strict.GetString($SourceBytes, $Utf8Offset, $Utf8Count) }
    catch { throw "Unable to decode UTF-8 file safely: $Path" }
}

# Escribe texto como UTF-8 sin BOM y verifica el resultado.
function Write-SabasUtf8NoBom {
    # Recibe ruta y contenido final.
    param(
        # Recibe la ruta de destino.
        [Parameter(Mandatory = $true)][string]$Path,
        # Recibe el texto ya validado.
        [Parameter(Mandatory = $true)][string]$Text
    )
    # Crea una codificación UTF-8 explícitamente sin BOM.
    $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    # Escribe el contenido sin pasar por Set-Content.
    [System.IO.File]::WriteAllText($Path, $Text, $Utf8NoBom)
    # Lee los primeros bytes para validar que no se haya introducido BOM.
    $WrittenBytes = [System.IO.File]::ReadAllBytes($Path)
    # Detecta exactamente EF BB BF.
    $HasUtf8Bom = ($WrittenBytes.Length -ge 3) -and ($WrittenBytes[0] -eq 0xEF) -and ($WrittenBytes[1] -eq 0xBB) -and ($WrittenBytes[2] -eq 0xBF)
    # Falla si la escritura no respetó el formato requerido por Codex.
    if ($HasUtf8Bom) { throw "UTF-8 BOM detected after writing: $Path" }
}

# Retira el Stop Hook de Codex conservando hooks ajenos y su texto Unicode.
function Remove-SabasCodexHook {
    # Define hooks.json.
    $HooksFile = Join-Path $CodexHome 'hooks.json'
    # Modifica solo si existe.
    if (Test-Path $HooksFile) {
        # Lee JSON como UTF-8 explícito para preservar caracteres no ASCII.
        $RawHooks = Read-SabasUtf8Text -Path $HooksFile
        # Parsea o crea objeto vacío.
        $ParsedHooks = if ([string]::IsNullOrWhiteSpace($RawHooks)) { @{} } else { $RawHooks | ConvertFrom-Json }
        # Normaliza.
        $HooksConfig = ConvertTo-SabasHashtable -InputObject $ParsedHooks
        # Rechaza raíz incompatible.
        if (-not ($HooksConfig -is [System.Collections.IDictionary])) { throw 'Codex hooks.json root is not an object.' }
        # Inicializa la marca que evita reescribir configuraciones donde no exista nuestro hook.
        $RemovedHookEntry = $false
        # Procesa sección hooks cuando existe.
        if ($HooksConfig.ContainsKey('hooks') -and ($HooksConfig['hooks'] -is [System.Collections.IDictionary])) {
            # Obtiene eventos.
            $Events = $HooksConfig['hooks']
            # Procesa Stop.
            if ($Events.ContainsKey('Stop')) {
                # Conserva el número original de entradas.
                $OriginalEntries = @($Events['Stop'])
                # Conserva entradas ajenas.
                $FilteredEntries = @($OriginalEntries | Where-Object { (($_ | ConvertTo-Json -Depth 20) -notmatch 'sabas_secure_stop\.py') })
                # Detecta si se retiró realmente una entrada Sabas.
                $RemovedHookEntry = $FilteredEntries.Count -ne $OriginalEntries.Count
                # Conserva Stop si quedan entradas.
                if ($FilteredEntries.Count -gt 0) { $Events['Stop'] = $FilteredEntries }
                # Elimina la clave si quedó vacía.
                elseif ($RemovedHookEntry) { $Events.Remove('Stop') }
            }
        }
        # Reescribe solo cuando había una entrada Sabas que retirar.
        if ($RemovedHookEntry) {
            # Conserva backup antes de modificar configuración compartida.
            Copy-Item -Force -Path $HooksFile -Destination (Join-Path $BackupRoot 'codex-hooks.json.bak')
            # Serializa el JSON preservado.
            $UpdatedHooksJson = $HooksConfig | ConvertTo-Json -Depth 20
            # Escribe en UTF-8 sin BOM para que Codex pueda parsearlo.
            Write-SabasUtf8NoBom -Path $HooksFile -Text $UpdatedHooksJson
            # Valida de nuevo como UTF-8/JSON después de escribir.
            $null = (Read-SabasUtf8Text -Path $HooksFile) | ConvertFrom-Json
            # Informa de la retirada segura.
            Write-Host "Removed Sabas Stop hook entry: $HooksFile"
        }
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
    # Recibe el home Hermes que discovery considera efectivo.
    param([Parameter(Mandatory = $true)][string]$ResolvedHermesHome)
    # Define la ruta instalada.
    $PluginTarget = Join-Path $ResolvedHermesHome 'plugins\sabas-secure-development'
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

# Retira Codex cuando está seleccionado directa o conjuntamente.
if (($Target -eq 'Codex') -or ($Target -eq 'Both') -or ($Target -eq 'All')) {
    # Elimina todas las skills propias, incluida la capa de eficiencia.
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

# Retira Hermes cuando está seleccionado directa o conjuntamente.
if (($Target -eq 'Hermes') -or ($Target -eq 'Both') -or ($Target -eq 'All')) {
    # Resuelve el home realmente usado por Hermes antes de retirar componentes.
    $HermesHome = Resolve-SabasHermesHome
    # Construye el árbol de skills del home efectivo.
    $HermesSkillsTarget = Join-Path $HermesHome 'skills'
    # Elimina todas las skills propias, incluida la capa de eficiencia.
    Remove-SabasOwnedSkills -SkillsTarget $HermesSkillsTarget -PlatformName 'Hermes'
    # Retira el plugin propio del mismo home efectivo.
    Remove-SabasHermesPlugin -ResolvedHermesHome $HermesHome
    # Retira torpe únicamente con autorización y marcador.
    if ($RemoveBundledUsuarioTorpe) { Remove-SabasBundledTorpe -SkillsTarget $HermesSkillsTarget -PlatformName 'Hermes' }
}

# Retira las Agent Skills globales de Antigravity cuando se selecciona ese destino o todos.
if (($Target -eq 'Antigravity') -or ($Target -eq 'All')) {
    # Elimina todas las skills propias del árbol global oficial.
    Remove-SabasOwnedSkills -SkillsTarget $AntigravitySkillsTarget -PlatformName 'Antigravity'
    # Retira torpe únicamente cuando se pidió y el marcador demuestra propiedad Sabas.
    if ($RemoveBundledUsuarioTorpe) { Remove-SabasBundledTorpe -SkillsTarget $AntigravitySkillsTarget -PlatformName 'Antigravity' }
}

# Aclara que las skills externas se preservan porque pueden usarse de forma independiente.
Write-Host 'External cybersecurity skills are intentionally left installed.'
# Informa de backups.
Write-Host "Backup directory: $BackupRoot"
# Confirma finalización.
Write-Host "Sabas Secure Development removed for target: $Target"
