# Declara el punto de entrada portable para instalar o actualizar el bundle Sabas.
param(
    # Selecciona si se trata de una instalación inicial o de una actualización idempotente.
    [ValidateSet('Install', 'Update')]
    [string]$Action = 'Install',
    # Selecciona el agente de destino; si se omite se muestra un menú.
    [ValidateSet('Codex', 'Hermes', 'Antigravity', 'All')]
    [string]$Target,
    # Solicita las skills defensivas externas para Codex/Hermes.
    [switch]$InstallExternalSkills,
    # Selecciona el perfil de skills defensivas externas.
    [ValidateSet('web', 'api', 'devsecops', 'all')]
    [string]$ExternalProfile = 'all',
    # Actualiza el bloque global AGENTS de Codex.
    [switch]$UpdateGlobalAgents,
    # Instala el Stop Hook de Codex.
    [switch]$InstallCompletionHook,
    # Permite reemplazos explícitos que el instalador principal protege por defecto.
    [switch]$Force
)

# Activa comprobaciones estrictas para detectar variables incorrectas.
Set-StrictMode -Version Latest
# Convierte errores no terminantes en excepciones para evitar estados parciales.
$ErrorActionPreference = 'Stop'
# Resuelve la raíz del paquete desde la carpeta scripts.
$PackageRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
# Genera una marca temporal para backups propios de este wrapper.
$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
# Define la carpeta de backup compartida por las integraciones portables.
$BackupRoot = Join-Path $HOME ".sabas-secure-development\backups\portable-$Timestamp"
# Define la fuente de las skills propias.
$SkillsSource = Join-Path $PackageRoot 'skills'
# Define la fuente de usuario-torpe-qa incluida como soporte.
$TorpeSource = Join-Path $PackageRoot 'support-skills\usuario-torpe-qa'
# Define el instalador probado de Codex/Hermes.
$CoreInstaller = Join-Path $PSScriptRoot 'Install-SabasSecureDev.ps1'
# Define la batería de autopruebas del bundle.
$SelfTest = Join-Path $PSScriptRoot 'Test-SabasSecureDev.ps1'

# Solicita un destino cuando no se indicó por parámetro.
if ([string]::IsNullOrWhiteSpace($Target)) {
    # Muestra la cabecera del selector.
    Write-Host 'Selecciona dónde aplicar Sabas Secure Development:'
    # Ofrece Codex.
    Write-Host '  1) Codex'
    # Ofrece Hermes Agent.
    Write-Host '  2) Hermes Agent'
    # Ofrece Google Antigravity IDE.
    Write-Host '  3) Google Antigravity IDE'
    # Ofrece todos los destinos.
    Write-Host '  4) Todos'
    # Lee la opción del usuario.
    $Choice = Read-Host 'Opción [1-4]'
    # Convierte la opción en el nombre estable del destino.
    switch ($Choice) {
        # Selecciona Codex.
        '1' { $Target = 'Codex' }
        # Selecciona Hermes.
        '2' { $Target = 'Hermes' }
        # Selecciona Antigravity.
        '3' { $Target = 'Antigravity' }
        # Selecciona todos.
        '4' { $Target = 'All' }
        # Rechaza cualquier otra opción.
        default { throw 'Invalid target selection.' }
    }
}

# Crea la carpeta de backup solo cuando vaya a ser necesaria.
New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null

# Copia una skill completa de forma idempotente y conserva la versión anterior.
function Install-SabasPortableSkill {
    # Declara los parámetros de copia.
    param(
        # Recibe el nombre exacto de la skill.
        [Parameter(Mandatory = $true)][string]$SkillName,
        # Recibe la carpeta raíz de skills del agente.
        [Parameter(Mandatory = $true)][string]$SkillsTarget,
        # Recibe la etiqueta de plataforma usada en mensajes y backups.
        [Parameter(Mandatory = $true)][string]$PlatformName
    )
    # Construye la ruta fuente de la skill.
    $Source = Join-Path $SkillsSource $SkillName
    # Exige el SKILL.md obligatorio antes de tocar el destino.
    if (-not (Test-Path (Join-Path $Source 'SKILL.md'))) { throw "Missing SKILL.md for $SkillName." }
    # Crea la carpeta raíz de skills cuando no existe.
    New-Item -ItemType Directory -Force -Path $SkillsTarget | Out-Null
    # Construye el destino final de la skill.
    $Destination = Join-Path $SkillsTarget $SkillName
    # Conserva la versión anterior cuando existe.
    if (Test-Path $Destination) {
        # Define el backup específico de la plataforma.
        $PlatformBackup = Join-Path $BackupRoot $PlatformName
        # Crea el directorio de backup.
        New-Item -ItemType Directory -Force -Path $PlatformBackup | Out-Null
        # Elimina un backup homónimo imposible de mezclar con la nueva copia.
        if (Test-Path (Join-Path $PlatformBackup $SkillName)) { Remove-Item -Recurse -Force -Path (Join-Path $PlatformBackup $SkillName) }
        # Copia la versión instalada antes de reemplazarla.
        Copy-Item -Recurse -Force -Path $Destination -Destination (Join-Path $PlatformBackup $SkillName)
        # Elimina la versión antigua para evitar archivos obsoletos.
        Remove-Item -Recurse -Force -Path $Destination
    }
    # Copia la versión incluida en el bundle.
    Copy-Item -Recurse -Force -Path $Source -Destination $Destination
    # Informa de la operación realizada.
    Write-Host "$Action [$PlatformName]: $SkillName"
}

# Instala usuario-torpe-qa sin sobrescribir una versión ajena ya existente.
function Install-SabasPortableTorpe {
    # Declara los parámetros de instalación.
    param(
        # Recibe la carpeta raíz de skills.
        [Parameter(Mandatory = $true)][string]$SkillsTarget,
        # Recibe la etiqueta de plataforma.
        [Parameter(Mandatory = $true)][string]$PlatformName
    )
    # Construye el destino de la skill.
    $Destination = Join-Path $SkillsTarget 'usuario-torpe-qa'
    # Preserva una instalación existente del usuario.
    if (Test-Path (Join-Path $Destination 'SKILL.md')) {
        # Informa de que no se sobrescribe una procedencia no demostrada.
        Write-Host "Existing usuario-torpe-qa preserved [$PlatformName]."
        # Sale sin modificarla.
        return
    }
    # Crea la carpeta raíz de skills.
    New-Item -ItemType Directory -Force -Path $SkillsTarget | Out-Null
    # Copia el soporte completo cuando no existía.
    Copy-Item -Recurse -Force -Path $TorpeSource -Destination $Destination
    # Informa de la instalación.
    Write-Host "$Action [$PlatformName]: usuario-torpe-qa"
}

# Localiza el árbol de skills de Hermes realmente utilizado por la instalación.
function Resolve-SabasHermesSkillsTarget {
    # Inicializa la lista de candidatos.
    $Candidates = New-Object System.Collections.Generic.List[string]
    # Añade HERMES_HOME cuando está definido.
    if (-not [string]::IsNullOrWhiteSpace($env:HERMES_HOME)) { $Candidates.Add((Join-Path $env:HERMES_HOME 'skills')) }
    # Pregunta a Hermes por su configuración efectiva cuando la CLI está disponible.
    if (Get-Command hermes -ErrorAction SilentlyContinue) {
        # Conserva la política de errores del wrapper.
        $PreviousErrorActionPreference = $ErrorActionPreference
        # Ejecuta la consulta de forma tolerante a stderr informativo.
        try {
            # Evita que Windows PowerShell 5.1 convierta stderr informativo en excepción.
            $ErrorActionPreference = 'Continue'
            # Captura la salida de config path.
            $ConfigOutput = @(& hermes config path 2>&1)
            # Conserva el código de salida real.
            $ConfigExitCode = $LASTEXITCODE
        }
        finally {
            # Restaura la política original.
            $ErrorActionPreference = $PreviousErrorActionPreference
        }
        # Procesa únicamente una respuesta correcta.
        if ($ConfigExitCode -eq 0) {
            # Recorre las líneas devueltas por Hermes.
            foreach ($Line in $ConfigOutput) {
                # Convierte la línea a texto limpio.
                $Text = ([string]$Line).Trim()
                # Detecta una ruta de configuración existente.
                if ($Text -match '(?i)([A-Z]:[\\/].*config\.ya?ml|/.*config\.ya?ml)\s*$') {
                    # Obtiene el home efectivo a partir del fichero de configuración.
                    $ResolvedHome = Split-Path -Parent $Matches[1]
                    # Añade su árbol de skills como candidato prioritario.
                    $Candidates.Add((Join-Path $ResolvedHome 'skills'))
                }
            }
        }
    }
    # Añade el layout Windows moderno cuando existe LOCALAPPDATA.
    if (($env:OS -eq 'Windows_NT') -and (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA))) { $Candidates.Add((Join-Path $env:LOCALAPPDATA 'hermes\skills')) }
    # Añade el layout histórico portable como último fallback.
    $Candidates.Add((Join-Path $HOME '.hermes\skills'))
    # Elimina duplicados preservando orden.
    $UniqueCandidates = @($Candidates | Select-Object -Unique)
    # Prefiere el árbol donde el instalador principal ya dejó sabas-secure-qa.
    foreach ($Candidate in $UniqueCandidates) {
        # Devuelve el primer árbol confirmado por una skill instalada.
        if (Test-Path (Join-Path $Candidate 'sabas-secure-qa\SKILL.md')) { return $Candidate }
    }
    # Devuelve el primer candidato cuando todavía no existe ninguna instalación previa.
    return $UniqueCandidates[0]
}

# Reescribe hooks.json de Codex en UTF-8 sin BOM y verifica que siga siendo JSON válido.
function Repair-SabasCodexHooksEncoding {
    # Respeta CODEX_HOME cuando está personalizado.
    $CodexHome = if ([string]::IsNullOrWhiteSpace($env:CODEX_HOME)) { Join-Path $HOME '.codex' } else { $env:CODEX_HOME }
    # Construye la ruta del JSON de hooks.
    $HooksFile = Join-Path $CodexHome 'hooks.json'
    # Sale cuando no existe ningún archivo que reparar.
    if (-not (Test-Path $HooksFile)) { return }
    # Lee el contenido completo sin alterar su estructura.
    $RawHooks = Get-Content -Raw -Path $HooksFile
    # Valida que el archivo siga siendo JSON antes de reescribirlo.
    if (-not [string]::IsNullOrWhiteSpace($RawHooks)) { $null = $RawHooks | ConvertFrom-Json }
    # Conserva una copia previa específica del wrapper.
    Copy-Item -Force -Path $HooksFile -Destination (Join-Path $BackupRoot 'codex-hooks-before-utf8-repair.json')
    # Crea una codificación UTF-8 explícitamente sin BOM.
    $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    # Reescribe exactamente el mismo JSON evitando el BOM que Codex rechaza.
    [System.IO.File]::WriteAllText($HooksFile, $RawHooks, $Utf8NoBom)
    # Lee los bytes resultantes para comprobar que no quede la firma UTF-8 BOM.
    $Bytes = [System.IO.File]::ReadAllBytes($HooksFile)
    # Detecta exactamente EF BB BF sin exigir que un JSON válido empiece por llave y sin romper archivos con espacios iniciales.
    $HasUtf8Bom = ($Bytes.Length -ge 3) -and ($Bytes[0] -eq 0xEF) -and ($Bytes[1] -eq 0xBB) -and ($Bytes[2] -eq 0xBF)
    # Detiene si la escritura .NET no eliminó la firma BOM.
    if ($HasUtf8Bom) { throw 'Codex hooks.json still contains an UTF-8 BOM after repair.' }
    # Informa de la reparación verificada.
    Write-Host 'Codex hooks.json encoding: UTF-8 without BOM (PASS)'
}

# Verifica que el hook runtime de Codex coincide byte a byte con el hook auditado del bundle.
function Test-SabasCodexHookIntegrity {
    # Respeta CODEX_HOME cuando está personalizado.
    $CodexHome = if ([string]::IsNullOrWhiteSpace($env:CODEX_HOME)) { Join-Path $HOME '.codex' } else { $env:CODEX_HOME }
    # Define el hook instalado.
    $InstalledHook = Join-Path $CodexHome 'hooks\sabas_secure_stop.py'
    # Define el hook auditado dentro del bundle.
    $BundledHook = Join-Path $PackageRoot 'scripts\SabasSecureStopHook.py'
    # Sale si el hook no fue instalado en esta configuración.
    if (-not (Test-Path $InstalledHook)) { return }
    # Calcula la huella de la copia instalada.
    $InstalledHash = (Get-FileHash -Algorithm SHA256 -Path $InstalledHook).Hash
    # Calcula la huella de la fuente auditada.
    $BundledHash = (Get-FileHash -Algorithm SHA256 -Path $BundledHook).Hash
    # Detiene si las dos copias no son idénticas.
    if ($InstalledHash -ne $BundledHash) { throw 'Installed Codex hook differs from the audited bundle copy.' }
    # Informa de la verificación y facilita revisar la confianza en /hooks.
    Write-Host "Codex Stop Hook SHA256: $InstalledHash (PASS)"
}

# Instala las skills Sabas en la ruta global oficial de Google Antigravity IDE.
function Install-SabasAntigravity {
    # Define la ruta global documentada por Antigravity para Agent Skills.
    $AntigravitySkillsTarget = Join-Path $HOME '.gemini\config\skills'
    # Ejecuta las autopruebas antes de una instalación exclusiva de Antigravity.
    if (-not (Test-Path $SelfTest)) { throw 'Missing Test-SabasSecureDev.ps1.' }
    # Valida el bundle completo antes de copiarlo.
    & $SelfTest -BundleRoot $PackageRoot
    # Detiene si la batería devolvió un código de error.
    if (-not $?) { throw 'Bundle self-test failed before Antigravity installation.' }
    # Recorre todas las skills propias que contienen SKILL.md.
    foreach ($SkillDirectory in Get-ChildItem -Path $SkillsSource -Directory) {
        # Instala únicamente directorios que realmente sean Agent Skills.
        if (Test-Path (Join-Path $SkillDirectory.FullName 'SKILL.md')) {
            # Copia la skill al árbol global oficial de Antigravity.
            Install-SabasPortableSkill -SkillName $SkillDirectory.Name -SkillsTarget $AntigravitySkillsTarget -PlatformName 'Antigravity'
        }
    }
    # Instala el soporte de usuario-torpe sin sobrescribir una copia ajena.
    Install-SabasPortableTorpe -SkillsTarget $AntigravitySkillsTarget -PlatformName 'Antigravity'
    # Informa de la ruta efectiva para facilitar la verificación manual.
    Write-Host "Antigravity skills path: $AntigravitySkillsTarget"
    # Aclara que esta integración no instala hooks externos al sandbox.
    Write-Host 'Antigravity integration installs Agent Skills only; it does not install the Codex Stop Hook or Hermes plugin.'
}

# Determina si hay que ejecutar el instalador principal de Codex/Hermes.
$NeedsCoreInstaller = ($Target -eq 'Codex') -or ($Target -eq 'Hermes') -or ($Target -eq 'All')

# Ejecuta el instalador principal cuando corresponde.
if ($NeedsCoreInstaller) {
    # Exige que el instalador principal forme parte del bundle.
    if (-not (Test-Path $CoreInstaller)) { throw 'Missing Install-SabasSecureDev.ps1.' }
    # Traduce All a Both porque el instalador principal gestiona Codex+Hermes.
    $CoreTarget = if ($Target -eq 'All') { 'Both' } else { $Target }
    # Prepara parámetros compatibles con el instalador principal.
    $CoreArguments = @{
        # Transfiere el destino.
        Target = $CoreTarget
        # Transfiere el perfil externo aunque no se solicite su instalación.
        ExternalProfile = $ExternalProfile
    }
    # Añade la solicitud de skills externas cuando corresponde.
    if ($InstallExternalSkills) { $CoreArguments['InstallExternalSkills'] = $true }
    # Añade la actualización de AGENTS de Codex cuando corresponde.
    if ($UpdateGlobalAgents) { $CoreArguments['UpdateGlobalAgents'] = $true }
    # Añade el Stop Hook de Codex cuando corresponde.
    if ($InstallCompletionHook) { $CoreArguments['InstallCompletionHook'] = $true }
    # Añade Force únicamente cuando el usuario lo solicitó.
    if ($Force) { $CoreArguments['Force'] = $true }
    # Ejecuta el instalador principal con sus protecciones y backups existentes.
    & $CoreInstaller @CoreArguments
    # Detiene si el instalador principal falló.
    if (-not $?) { throw 'Core Codex/Hermes installation failed.' }
}

# Completa sabas-efficient-development en Codex porque el motor V0.5.4 solo administraba las tres skills de seguridad originales.
if (($Target -eq 'Codex') -or ($Target -eq 'All')) {
    # Define el árbol estándar compartido por Codex CLI/IDE.
    $CodexSkillsTarget = Join-Path $HOME '.agents\skills'
    # Instala o actualiza la skill de eficiencia.
    Install-SabasPortableSkill -SkillName 'sabas-efficient-development' -SkillsTarget $CodexSkillsTarget -PlatformName 'Codex'
    # Repara la codificación del JSON de hooks aunque proceda de una instalación V0.5.4 anterior.
    Repair-SabasCodexHooksEncoding
    # Verifica la integridad del hook cuando existe.
    Test-SabasCodexHookIntegrity
}

# Completa sabas-efficient-development en el home efectivo de Hermes.
if (($Target -eq 'Hermes') -or ($Target -eq 'All')) {
    # Localiza el árbol que realmente usa Hermes.
    $HermesSkillsTarget = Resolve-SabasHermesSkillsTarget
    # Instala o actualiza la skill de eficiencia.
    Install-SabasPortableSkill -SkillName 'sabas-efficient-development' -SkillsTarget $HermesSkillsTarget -PlatformName 'Hermes'
}

# Instala Antigravity cuando fue seleccionado explícitamente o mediante All.
if (($Target -eq 'Antigravity') -or ($Target -eq 'All')) {
    # Ejecuta la integración basada únicamente en Agent Skills.
    Install-SabasAntigravity
}

# Informa de la operación completada.
Write-Host "Sabas portable setup completed: Action=$Action Target=$Target"
# Informa de la ubicación de backups creada por el wrapper.
Write-Host "Portable backup directory: $BackupRoot"
