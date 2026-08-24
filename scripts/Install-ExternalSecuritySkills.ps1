# Declara parámetros para instalar un perfil defensivo allowlisted en Codex, Hermes o ambos.
param(
    # Limita el perfil a conjuntos definidos en el lockfile.
    [ValidateSet('web', 'api', 'devsecops', 'all')]
    [string]$Profile = 'web',
    # Selecciona el árbol o árboles de skills donde se copiarán las skills externas.
    [ValidateSet('Codex', 'Hermes', 'Both')]
    [string]$Target = 'Codex',
    # Permite que el instalador principal pase el HERMES_HOME ya resuelto por la propia CLI/perfil.
    [string]$HermesHomeOverride,
    # Permite reemplazar una copia existente de distinta procedencia conservando backup.
    [switch]$Force
)

# Activa comprobaciones estrictas de PowerShell.
Set-StrictMode -Version Latest
# Convierte errores en fallos terminantes.
$ErrorActionPreference = 'Stop'

# Ejecuta Git capturando stdout/stderr sin permitir que mensajes informativos rompan Windows PowerShell 5.1.
function Invoke-SabasExternalNativeCapture {
    # Declara comando y argumentos separados.
    param(
        # Recibe el ejecutable nativo.
        [Parameter(Mandatory = $true)][string]$Command,
        # Recibe los argumentos sin construir una cadena de shell.
        [string[]]$Arguments = @()
    )
    # Conserva la política estricta para restaurarla tras la llamada.
    $PreviousNativeErrorActionPreference = $ErrorActionPreference
    # Garantiza restauración incluso ante un fallo de lanzamiento.
    try {
        # Evita que stderr informativo se convierta en excepción terminante en PowerShell 5.1.
        $ErrorActionPreference = 'Continue'
        # Resuelve el comando antes de lanzarlo.
        $ResolvedNativeCommand = Get-Command $Command -ErrorAction Stop
        # Usa la ruta física cuando existe para máxima compatibilidad con Windows PowerShell 5.1.
        $ResolvedNativePath = if (-not [string]::IsNullOrWhiteSpace([string]$ResolvedNativeCommand.Source)) { [string]$ResolvedNativeCommand.Source } else { $Command }
        # Ejecuta sin shell y captura ambas corrientes únicamente dentro de este wrapper.
        $NativeOutput = @(& $ResolvedNativePath @Arguments 2>&1)
        # Conserva inmediatamente el código de salida real.
        $NativeExitCode = $LASTEXITCODE
        # Convierte stdout y ErrorRecord de stderr a texto homogéneo.
        $NativeLines = @(foreach ($NativeItem in $NativeOutput) {
            # Extrae el mensaje nativo cuando PowerShell encapsuló stderr.
            if ($NativeItem -is [System.Management.Automation.ErrorRecord]) {
                # Obtiene el mensaje más directo disponible.
                $NativeMessage = [string]$NativeItem.Exception.Message
                # Usa la representación completa únicamente como fallback.
                if ([string]::IsNullOrWhiteSpace($NativeMessage)) { $NativeMessage = [string]$NativeItem }
                # Emite la línea recuperada.
                $NativeMessage
            }
            else {
                # Conserva stdout normal.
                [string]$NativeItem
            }
        })
        # Devuelve el resultado estable basado en exit code.
        return [PSCustomObject]@{ ExitCode = [int]$NativeExitCode; Lines = $NativeLines; Text = ($NativeLines -join [Environment]::NewLine) }
    }
    catch {
        # Convierte un fallo de lanzamiento en un código controlado.
        $NativeFailure = [string]$_.Exception.Message
        # Devuelve el fallo sin confundirlo con stderr ordinario.
        return [PSCustomObject]@{ ExitCode = 127; Lines = @($NativeFailure); Text = $NativeFailure }
    }
    finally {
        # Restaura la política estricta del instalador externo.
        $ErrorActionPreference = $PreviousNativeErrorActionPreference
    }
}

# Resuelve la raíz del bundle.
$PackageRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
# Define el lockfile como única fuente de verdad de supply chain.
$LockFile = Join-Path $PackageRoot 'EXTERNAL-SKILLS.lock.json'
# Exige que el lockfile exista.
if (-not (Test-Path $LockFile)) { throw 'Missing EXTERNAL-SKILLS.lock.json.' }
# Carga la configuración fijada.
$Lock = Get-Content -Raw -Path $LockFile | ConvertFrom-Json
# Obtiene el repositorio autorizado.
$Repository = [string]$Lock.source_repository
# Obtiene el commit completo fijado.
$PinnedCommit = [string]$Lock.pinned_commit
# Rechaza un commit abreviado o malformado.
if ($PinnedCommit -notmatch '^[0-9a-f]{40}$') { throw "Invalid pinned commit in lockfile: $PinnedCommit" }
# Prioriza el HERMES_HOME resuelto por el instalador principal cuando se proporciona.
if (-not [string]::IsNullOrWhiteSpace($HermesHomeOverride)) {
    # Usa exactamente el perfil/home ya validado.
    $HermesHome = $HermesHomeOverride
}
elseif (-not [string]::IsNullOrWhiteSpace($env:HERMES_HOME)) {
    # Respeta un override explícito del entorno.
    $HermesHome = $env:HERMES_HOME
}
elseif ($env:OS -eq 'Windows_NT') {
    # En Windows Hermes usa %LOCALAPPDATA%\hermes por defecto.
    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) { $HermesHome = Join-Path $env:LOCALAPPDATA 'hermes' }
    else { $HermesHome = Join-Path $HOME 'AppData\Local\hermes' }
}
else {
    # En POSIX mantiene ~/.hermes.
    $HermesHome = Join-Path $HOME '.hermes'
}
# Define el destino estándar de Codex.
$CodexSkillsTarget = Join-Path $HOME '.agents\skills'
# Define el destino estándar de Hermes.
$HermesSkillsTarget = Join-Path $HermesHome 'skills'
# Genera una marca temporal para backup y clon temporal.
$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
# Define la carpeta neutral de backups.
$BackupRoot = Join-Path $HOME ".sabas-secure-development\backups\external-$Timestamp"
# Define la carpeta temporal de clon.
$TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "sabas-cyber-skills-$Timestamp"

# Convierte los perfiles fijados a arrays normales de PowerShell.
$WebSkills = @($Lock.profiles.web)
# Obtiene el add-on API.
$ApiSkills = @($Lock.profiles.api_addon)
# Obtiene el add-on DevSecOps.
$DevSecOpsSkills = @($Lock.profiles.devsecops_addon)
# Selecciona el conjunto de skills solicitado.
switch ($Profile) {
    # Usa solo el núcleo web.
    'web' { $SelectedSkills = $WebSkills }
    # Añade seguridad API al núcleo web.
    'api' { $SelectedSkills = $WebSkills + $ApiSkills }
    # Añade seguridad DevSecOps al núcleo web.
    'devsecops' { $SelectedSkills = $WebSkills + $DevSecOpsSkills }
    # Combina los tres grupos.
    'all' { $SelectedSkills = $WebSkills + $ApiSkills + $DevSecOpsSkills }
}
# Elimina duplicados y ordena de forma determinista.
$SelectedSkills = @($SelectedSkills | Sort-Object -Unique)
# Construye la lista de destinos elegidos.
$SkillTargets = @()
# Añade Codex cuando procede.
if (($Target -eq 'Codex') -or ($Target -eq 'Both')) {
    # Registra el destino como objeto simple.
    $SkillTargets += [PSCustomObject]@{ Name = 'Codex'; Path = $CodexSkillsTarget }
}
# Añade Hermes cuando procede.
if (($Target -eq 'Hermes') -or ($Target -eq 'Both')) {
    # Registra el destino como objeto simple.
    $SkillTargets += [PSCustomObject]@{ Name = 'Hermes'; Path = $HermesSkillsTarget }
}
# Rechaza un estado sin destinos por seguridad defensiva.
if ($SkillTargets.Count -eq 0) { throw 'No valid skill target selected.' }
# Exige Git antes de acceder al repositorio externo.
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'Git is required to install the pinned external security skills.' }
# Crea la carpeta de backup.
New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null
# Limpia una carpeta temporal previa improbable.
if (Test-Path $TempRoot) { Remove-Item -Recurse -Force -Path $TempRoot }

# Garantiza la limpieza del clon temporal incluso si una validación falla.
try {
    # Clona sin checkout mediante el wrapper tolerante a stderr informativo.
    $CloneResult = Invoke-SabasExternalNativeCapture -Command 'git' -Arguments @('clone', '--filter=blob:none', '--no-checkout', $Repository, $TempRoot)
    # Comprueba exclusivamente el exit code real de Git.
    if ([int]$CloneResult.ExitCode -ne 0) { throw ('Unable to clone the external skills repository. ' + $CloneResult.Text) }
    # Coloca el repositorio exactamente en el commit fijado.
    $CheckoutResult = Invoke-SabasExternalNativeCapture -Command 'git' -Arguments @('-C', $TempRoot, 'checkout', '--detach', $PinnedCommit)
    # Comprueba exclusivamente el exit code real del checkout.
    if ([int]$CheckoutResult.ExitCode -ne 0) { throw ("Unable to checkout pinned commit $PinnedCommit. " + $CheckoutResult.Text) }
    # Obtiene el SHA real sin dejar que warnings de Git contaminen la selección.
    $RevParseResult = Invoke-SabasExternalNativeCapture -Command 'git' -Arguments @('-C', $TempRoot, 'rev-parse', 'HEAD')
    # Exige un código de salida correcto antes de interpretar stdout/stderr.
    if ([int]$RevParseResult.ExitCode -ne 0) { throw ('Unable to resolve the checked-out commit. ' + $RevParseResult.Text) }
    # Selecciona únicamente una línea que sea un SHA completo.
    $ResolvedCommit = [string](@($RevParseResult.Lines | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ -match '^[0-9a-f]{40}$' } | Select-Object -Last 1))
    # Exige que Git haya devuelto una identidad interpretable.
    if ([string]::IsNullOrWhiteSpace($ResolvedCommit)) { throw 'Git rev-parse did not return a full commit SHA.' }
    # Exige coincidencia exacta con el lockfile.
    if ($ResolvedCommit -ne $PinnedCommit) { throw "Pinned commit verification failed. Expected $PinnedCommit but got $ResolvedCommit." }
    # Confirma la verificación supply-chain.
    Write-Host "Verified upstream commit: $ResolvedCommit"

    # Valida todas las fuentes allowlisted antes de modificar cualquier árbol local.
    foreach ($SkillName in $SelectedSkills) {
        # Construye la carpeta fuente fijada.
        $Source = Join-Path $TempRoot "skills\$SkillName"
        # Define el SKILL.md esperado.
        $SkillDocumentPath = Join-Path $Source 'SKILL.md'
        # Exige que la skill exista en el commit fijado.
        if (-not (Test-Path $SkillDocumentPath)) { throw "Pinned upstream does not contain expected skill: $SkillName" }
        # Lee el documento de instrucciones.
        $SkillDocument = Get-Content -Raw -Path $SkillDocumentPath
        # Extrae la línea name mediante una regex sin comillas interpoladas problemáticas en PowerShell 5.1.
        $NameMatch = [Regex]::Match($SkillDocument, '(?m)^name:\s*(?<value>[^\r\n]+?)\s*$')
        # Exige una identidad declarada.
        if (-not $NameMatch.Success) { throw "Skill name missing in pinned upstream: $SkillName" }
        # Normaliza el valor YAML declarado.
        $DeclaredSkillName = $NameMatch.Groups['value'].Value.Trim()
        # Elimina comillas simples exteriores si existen.
        $DeclaredSkillName = $DeclaredSkillName.Trim("'")
        # Elimina comillas dobles exteriores si existen.
        $DeclaredSkillName = $DeclaredSkillName.Trim('"')
        # Exige coincidencia exacta entre nombre y carpeta allowlisted.
        if ($DeclaredSkillName -ne [string]$SkillName) { throw "Skill name mismatch in pinned upstream: $SkillName" }
    }

    # Recorre cada plataforma seleccionada tras validar todas las fuentes.
    foreach ($TargetInfo in $SkillTargets) {
        # Obtiene la etiqueta de plataforma.
        $PlatformName = [string]$TargetInfo.Name
        # Obtiene el directorio de skills.
        $SkillsTarget = [string]$TargetInfo.Path
        # Crea el directorio destino.
        New-Item -ItemType Directory -Force -Path $SkillsTarget | Out-Null
        # Crea el backup específico de la plataforma.
        $PlatformBackupRoot = Join-Path $BackupRoot $PlatformName
        # Crea su carpeta.
        New-Item -ItemType Directory -Force -Path $PlatformBackupRoot | Out-Null
        # Recorre las skills ya validadas.
        foreach ($SkillName in $SelectedSkills) {
            # Construye la fuente exacta.
            $Source = Join-Path $TempRoot "skills\$SkillName"
            # Construye el destino concreto.
            $Destination = Join-Path $SkillsTarget $SkillName
            # Inicializa el estado de reemplazo.
            $ReplaceExisting = $false
            # Gestiona una instalación previa.
            if (Test-Path $Destination) {
                # Define el marcador de procedencia Sabas.
                $ExistingProvenancePath = Join-Path $Destination '.sabas-source-lock.json'
                # Comprueba si ya coincide exactamente con el pin actual.
                if (Test-Path $ExistingProvenancePath) {
                    # Lee la procedencia instalada.
                    $ExistingProvenance = Get-Content -Raw -Path $ExistingProvenancePath | ConvertFrom-Json
                    # Omite la copia si ya es exactamente la versión fijada.
                    if (([string]$ExistingProvenance.pinned_commit -eq $PinnedCommit) -and ([string]$ExistingProvenance.skill -eq [string]$SkillName)) {
                        # Informa del estado idempotente.
                        Write-Host "Already pinned and installed [$PlatformName]: $SkillName"
                        # Continúa con la siguiente skill.
                        continue
                    }
                }
                # Preserva una skill de otra procedencia salvo autorización explícita.
                if (-not $Force) {
                    # Informa sin sustituirla.
                    Write-Warning "Existing skill not replaced without -Force [$PlatformName]: $SkillName"
                    # Continúa con la siguiente skill.
                    continue
                }
                # Autoriza reemplazo tras backup.
                $ReplaceExisting = $true
            }
            # Conserva la copia existente cuando va a ser reemplazada.
            if ($ReplaceExisting) {
                # Copia la skill instalada al backup.
                Copy-Item -Recurse -Force -Path $Destination -Destination (Join-Path $PlatformBackupRoot $SkillName)
                # Elimina la versión anterior para evitar mezcla de archivos.
                Remove-Item -Recurse -Force -Path $Destination
            }
            # Copia únicamente la skill allowlisted.
            Copy-Item -Recurse -Force -Path $Source -Destination $Destination
            # Construye metadatos de procedencia.
            $Provenance = [ordered]@{
                # Registra el repositorio exacto.
                source_repository = $Repository
                # Registra el commit verificado.
                pinned_commit = $PinnedCommit
                # Registra la skill exacta.
                skill = [string]$SkillName
                # Registra el destino para auditoría local.
                target = $PlatformName
                # Registra la versión del esquema.
                schema_version = 2
            }
            # Guarda la procedencia dentro de la skill sin modificar su SKILL.md upstream.
            Set-Content -Path (Join-Path $Destination '.sabas-source-lock.json') -Value ($Provenance | ConvertTo-Json) -Encoding utf8
            # Informa de la instalación.
            Write-Host "Installed external skill [$PlatformName]: $SkillName"
        }
    }
    # Informa del perfil procesado.
    Write-Host "External profile '$Profile' processed with $($SelectedSkills.Count) allowlisted skills for target $Target."
    # Informa de la carpeta de backups.
    Write-Host "External skills backup directory: $BackupRoot"
}
finally {
    # Elimina siempre el clon temporal cuando exista.
    if (Test-Path $TempRoot) { Remove-Item -Recurse -Force -Path $TempRoot }
}

# Recomienda reiniciar los agentes para refrescar discovery.
Write-Host 'Restart/reload Codex and/or Hermes if the new skills are not immediately discoverable.'
