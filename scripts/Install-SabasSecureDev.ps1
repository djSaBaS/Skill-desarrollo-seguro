# Declara los parámetros públicos del instalador multiplataforma de agentes.
param(
    # Permite seleccionar Codex, Hermes o ambos; si se omite se muestra un menú interactivo.
    [ValidateSet('Codex', 'Hermes', 'Both')]
    [string]$Target,
    # Permite instalar el conjunto allowlisted de skills externas defensivas.
    [switch]$InstallExternalSkills,
    # Selecciona el perfil externo; all instala las 20 skills defensivas fijadas por lockfile.
    [ValidateSet('web', 'api', 'devsecops', 'all')]
    [string]$ExternalProfile = 'all',
    # Añade o actualiza las instrucciones globales de seguridad de Codex cuando Codex está seleccionado.
    [switch]$UpdateGlobalAgents,
    # Instala el hook Stop de Codex cuando Codex está seleccionado.
    [switch]$InstallCompletionHook,
    # Permite reemplazar skills externas existentes de procedencia distinta, conservando backup.
    [switch]$Force
)

# Activa comprobaciones estrictas para detectar variables o propiedades incorrectas.
Set-StrictMode -Version Latest
# Convierte errores no terminantes en excepciones para evitar instalaciones parciales silenciosas.
$ErrorActionPreference = 'Stop'

# Resuelve la raíz del paquete desde la carpeta scripts.
$PackageRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
# Genera una marca temporal común para todos los backups de esta ejecución.
$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
# Permite redirigir backups únicamente para pruebas/automatización controlada sin cambiar destinos de agentes.
$BackupBase = if ([string]::IsNullOrWhiteSpace($env:SABAS_SECURE_BACKUP_ROOT)) { Join-Path $HOME '.sabas-secure-development\backups' } else { $env:SABAS_SECURE_BACKUP_ROOT }
# Define una ubicación neutral de backups que sirve tanto para Codex como para Hermes.
$BackupRoot = Join-Path $BackupBase $Timestamp
# Valida con el parser de esta misma versión de PowerShell todos los scripts auxiliares antes de modificar agentes.
$PowerShellScripts = @(Get-ChildItem -Path (Join-Path $PackageRoot 'scripts') -Filter '*.ps1' -File)
# Recorre cada script PowerShell distribuido.
foreach ($PowerShellScript in $PowerShellScripts) {
    # Inicializa la colección de tokens que rellenará el parser.
    $ParserTokens = $null
    # Inicializa la colección de errores que rellenará el parser.
    $ParserErrors = $null
    # Analiza el archivo sin ejecutarlo.
    [System.Management.Automation.Language.Parser]::ParseFile($PowerShellScript.FullName, [ref]$ParserTokens, [ref]$ParserErrors) | Out-Null
    # Comprueba si existe al menos un error sintáctico.
    if (@($ParserErrors).Count -gt 0) {
        # Construye un diagnóstico compacto con línea y columna.
        $ParserDetails = @($ParserErrors | ForEach-Object { $_.Message + ' at ' + $_.Extent.StartLineNumber + ':' + $_.Extent.StartColumnNumber }) -join '; '
        # Detiene antes de instalar ningún componente.
        throw "PowerShell syntax validation failed for $($PowerShellScript.Name): $ParserDetails"
    }
}
# Confirma la validación sintáctica previa.
Write-Host "PowerShell syntax validation: PASS ($($PowerShellScripts.Count) scripts)"

# Define la carpeta de skills propias dentro del bundle.
$SkillsSource = Join-Path $PackageRoot 'skills'
# Define la copia de soporte de usuario-torpe-qa incluida en el bundle.
$TorpeSupportSource = Join-Path $PackageRoot 'support-skills\usuario-torpe-qa'
# Respeta CODEX_HOME cuando está personalizado.
$CodexHome = if ([string]::IsNullOrWhiteSpace($env:CODEX_HOME)) { Join-Path $HOME '.codex' } else { $env:CODEX_HOME }

# Elimina secuencias ANSI de una salida CLI antes de analizar rutas o estados.
function Remove-SabasAnsi {
    # Declara el texto de entrada.
    param([AllowNull()][string]$Text)
    # Devuelve vacío para valores nulos.
    if ($null -eq $Text) { return '' }
    # Elimina códigos CSI usados por Rich/Colorama.
    return [Regex]::Replace($Text, '\x1B\[[0-?]*[ -/]*[@-~]', '')
}

# Ejecuta un programa nativo capturando stdout y stderr sin convertir stderr informativo en una excepción de Windows PowerShell 5.1.
function Invoke-SabasNativeCapture {
    # Declara el comando, sus argumentos y variables de entorno temporales.
    param(
        # Recibe un nombre resoluble por PATH o una ruta de ejecutable.
        [Parameter(Mandatory = $true)][string]$Command,
        # Recibe cada argumento por separado para evitar concatenación insegura.
        [string[]]$Arguments = @(),
        # Permite activar variables únicamente durante esta llamada, por ejemplo HERMES_PLUGINS_DEBUG.
        [hashtable]$EnvironmentVariables = @{}
    )
    # Conserva la política de errores del llamador porque PowerShell 5.1 trata stderr redirigido como ErrorRecord.
    $PreviousErrorActionPreference = $ErrorActionPreference
    # Conserva la codificación que PowerShell usa para comunicarse con programas nativos.
    $PreviousOutputEncoding = $OutputEncoding
    # Inicializa el estado de la codificación de consola para poder restaurarlo de forma segura.
    $PreviousConsoleOutputEncoding = $null
    # Registra si fue posible leer la codificación de consola actual.
    $ConsoleEncodingCaptured = $false
    # Guarda el estado previo de cualquier variable de entorno temporal.
    $EnvironmentBackup = @{}
    # Garantiza restauración de política, entorno y codificación aunque el programa falle.
    try {
        # Evita que una línea legítima de stderr de un programa nativo se convierta en excepción terminante.
        $ErrorActionPreference = 'Continue'
        # Intenta usar UTF-8 para decodificar correctamente la salida de CLIs modernas como Hermes.
        try {
            # Conserva la codificación real de la consola.
            $PreviousConsoleOutputEncoding = [Console]::OutputEncoding
            # Marca que la restauración posterior es segura.
            $ConsoleEncodingCaptured = $true
            # Construye UTF-8 sin BOM para pipes nativos.
            $Utf8Encoding = New-Object System.Text.UTF8Encoding($false)
            # Configura la salida de consola durante la llamada nativa.
            [Console]::OutputEncoding = $Utf8Encoding
            # Configura también la codificación de entrada/salida nativa usada por PowerShell.
            $OutputEncoding = $Utf8Encoding
        }
        catch {
            # Continúa con la codificación existente en hosts que no permiten modificar Console.OutputEncoding.
        }
        # Aplica variables de entorno temporales sin contaminar la sesión del usuario.
        foreach ($EnvironmentName in $EnvironmentVariables.Keys) {
            # Construye la ruta del proveedor Env:.
            $EnvironmentPath = 'Env:' + [string]$EnvironmentName
            # Registra si la variable existía antes de la llamada.
            $EnvironmentExisted = Test-Path $EnvironmentPath
            # Inicializa el valor previo como nulo cuando la variable no existía.
            $PreviousEnvironmentValue = $null
            # Lee el valor únicamente cuando la variable estaba definida.
            if ($EnvironmentExisted) { $PreviousEnvironmentValue = (Get-Item $EnvironmentPath).Value }
            # Guarda existencia y valor previo para restauración exacta.
            $EnvironmentBackup[[string]$EnvironmentName] = [PSCustomObject]@{ Existed = $EnvironmentExisted; Value = $PreviousEnvironmentValue }
            # Establece el valor temporal solicitado.
            Set-Item -Path $EnvironmentPath -Value ([string]$EnvironmentVariables[$EnvironmentName])
        }
        # Resuelve el comando antes de ejecutarlo para distinguir un binario ausente de un código de salida real.
        $ResolvedNativeCommand = Get-Command $Command -ErrorAction Stop
        # Usa la ruta física cuando está disponible para evitar diferencias al invocar objetos CommandInfo en PowerShell 5.1.
        $ResolvedNativePath = if (-not [string]::IsNullOrWhiteSpace([string]$ResolvedNativeCommand.Source)) { [string]$ResolvedNativeCommand.Source } else { $Command }
        # Ejecuta sin shell intermedio y fusiona stderr solo dentro de este wrapper tolerante a PowerShell 5.1.
        $CapturedNativeOutput = @(& $ResolvedNativePath @Arguments 2>&1)
        # Conserva el código de salida inmediatamente antes de cualquier otro comando nativo.
        $NativeExitCode = $LASTEXITCODE
        # Convierte ErrorRecord de stderr y strings de stdout a líneas de texto homogéneas.
        $NativeLines = @(foreach ($NativeItem in $CapturedNativeOutput) {
            # Extrae el texto original cuando Windows PowerShell encapsuló stderr como ErrorRecord.
            if ($NativeItem -is [System.Management.Automation.ErrorRecord]) {
                # Prioriza el mensaje de la excepción porque contiene la línea nativa sin el formato visual de PowerShell.
                $NativeMessage = [string]$NativeItem.Exception.Message
                # Usa la representación completa únicamente si la excepción no aportó texto.
                if ([string]::IsNullOrWhiteSpace($NativeMessage)) { $NativeMessage = [string]$NativeItem }
                # Emite la línea normalizada dentro del array de resultados.
                $NativeMessage
            }
            else {
                # Conserva stdout normal como texto.
                [string]$NativeItem
            }
        })
        # Devuelve un objeto estable para que el llamador decida por código de salida, nunca por presencia de stderr.
        return [PSCustomObject]@{ ExitCode = [int]$NativeExitCode; Lines = $NativeLines; Text = ($NativeLines -join [Environment]::NewLine) }
    }
    catch {
        # Convierte únicamente fallos de lanzamiento/PowerShell en un resultado controlado equivalente a command-not-found.
        $FailureLine = [string]$_.Exception.Message
        # Devuelve un código no cero sin interrumpir el instalador por una peculiaridad de captura.
        return [PSCustomObject]@{ ExitCode = 127; Lines = @($FailureLine); Text = $FailureLine }
    }
    finally {
        # Restaura cada variable de entorno temporal exactamente a su estado previo.
        foreach ($EnvironmentName in $EnvironmentBackup.Keys) {
            # Recupera el snapshot de esa variable.
            $EnvironmentState = $EnvironmentBackup[$EnvironmentName]
            # Construye de nuevo su ruta Env:.
            $EnvironmentPath = 'Env:' + [string]$EnvironmentName
            # Restaura el valor cuando existía previamente.
            if ($EnvironmentState.Existed) { Set-Item -Path $EnvironmentPath -Value ([string]$EnvironmentState.Value) }
            # Elimina la variable cuando fue creada únicamente para esta llamada.
            else { Remove-Item -Path $EnvironmentPath -ErrorAction SilentlyContinue }
        }
        # Restaura la codificación de PowerShell usada con programas nativos.
        $OutputEncoding = $PreviousOutputEncoding
        # Restaura la codificación de consola solo si pudo capturarse antes.
        if ($ConsoleEncodingCaptured) {
            # Evita que un host peculiar convierta la restauración en un nuevo fallo.
            try { [Console]::OutputEncoding = $PreviousConsoleOutputEncoding } catch { }
        }
        # Restaura la política estricta global del instalador.
        $ErrorActionPreference = $PreviousErrorActionPreference
    }
}

# Comprueba en Windows el mismo escenario que provocó NativeCommandError antes de modificar ningún agente.
if ($env:OS -eq 'Windows_NT') {
    # Ejecuta cmd.exe haciendo que escriba deliberadamente una línea en stderr y salga correctamente con código cero.
    $NativeStderrProbe = Invoke-SabasNativeCapture -Command 'cmd.exe' -Arguments @('/d', '/c', 'echo SABAS_NATIVE_STDERR_PROBE 1>&2 & exit /b 0')
    # Exige conservar el código de salida correcto del proceso nativo.
    if ([int]$NativeStderrProbe.ExitCode -ne 0) { throw 'Native stderr compatibility probe failed before installation.' }
    # Exige haber capturado la línea de stderr como datos y no haberla perdido o escalado a excepción.
    if ($NativeStderrProbe.Text -notmatch [Regex]::Escape('SABAS_NATIVE_STDERR_PROBE')) { throw 'Native stderr compatibility probe did not capture stderr safely.' }
    # Confirma que esta sesión de Windows PowerShell puede continuar con llamadas Hermes/Git seguras.
    Write-Host 'Native stderr compatibility probe: PASS'
}

# Resuelve el HERMES_HOME efectivo combinando configuración, discovery real y fallbacks compatibles.
function Resolve-SabasHermesHome {
    # Inicializa candidatos únicos manteniendo el orden de preferencia.
    $Candidates = New-Object System.Collections.Generic.List[object]
    # Define un helper local para añadir rutas no vacías sin duplicados.
    function Add-SabasHermesHomeCandidate {
        # Declara ruta y origen del candidato.
        param([string]$Path, [string]$Source)
        # Ignora rutas vacías.
        if ([string]::IsNullOrWhiteSpace($Path)) { return }
        # Expande variables de entorno incrustadas cuando existan.
        $ExpandedPath = [Environment]::ExpandEnvironmentVariables($Path.Trim().Trim([char]34))
        # Compara rutas de forma tolerante a mayúsculas en Windows.
        foreach ($ExistingCandidate in $Candidates) {
            # No añade un duplicado lógico.
            if ([string]::Equals([string]$ExistingCandidate.Path, $ExpandedPath, [System.StringComparison]::OrdinalIgnoreCase)) { return }
        }
        # Añade el candidato con su procedencia para diagnóstico.
        $Candidates.Add([PSCustomObject]@{ Path = $ExpandedPath; Source = $Source })
    }
    # Localiza la CLI de Hermes si está disponible.
    $HermesExecutable = Get-Command hermes -ErrorAction SilentlyContinue
    # Pregunta primero por el config efectivo; en versiones modernas respeta perfiles activos.
    if ($null -ne $HermesExecutable) {
        # Evita que una versión antigua sin `config path` interrumpa la resolución.
        try {
            # Obtiene stdout/stderr sin permitir que stderr informativo rompa Windows PowerShell 5.1.
            $ConfigPathResult = Invoke-SabasNativeCapture -Command 'hermes' -Arguments @('config', 'path')
            # Expone las líneas capturadas al parser de rutas.
            $ConfigPathOutput = @($ConfigPathResult.Lines)
            # Conserva el código de salida real del proceso Hermes.
            $ConfigPathExitCode = [int]$ConfigPathResult.ExitCode
            # Solo interpreta una respuesta correcta.
            if ($ConfigPathExitCode -eq 0) {
                # Recorre líneas porque algunas versiones añaden texto auxiliar.
                foreach ($ConfigPathLine in $ConfigPathOutput) {
                    # Limpia ANSI y espacios.
                    $CleanConfigPathLine = (Remove-SabasAnsi ([string]$ConfigPathLine)).Trim()
                    # Extrae una ruta Windows acabada en config.yaml/config.yml.
                    if ($CleanConfigPathLine -match '(?i)([A-Z]:[\\/].*config\.ya?ml)\s*$') {
                        # Añade el directorio padre como primera opción.
                        Add-SabasHermesHomeCandidate -Path (Split-Path -Parent $Matches[1]) -Source 'hermes config path'
                    }
                    # Extrae una ruta POSIX acabada en config.yaml/config.yml.
                    elseif ($CleanConfigPathLine -match '(?i)(/.*config\.ya?ml)\s*$') {
                        # Añade el directorio padre como primera opción.
                        Add-SabasHermesHomeCandidate -Path (Split-Path -Parent $Matches[1]) -Source 'hermes config path'
                    }
                }
            }
        }
        catch {
            # Continúa: `config path` no existe en todas las versiones de Hermes.
        }
    }
    # Respeta un HERMES_HOME explícito como siguiente fuente fuerte.
    Add-SabasHermesHomeCandidate -Path $env:HERMES_HOME -Source 'HERMES_HOME environment variable'
    # Añade los dos layouts conocidos en Windows porque versiones antiguas y actuales pueden diferir.
    if ($env:OS -eq 'Windows_NT') {
        # Añade la ubicación nativa actual de Hermes cuando LOCALAPPDATA está disponible.
        if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
            # Registra %LOCALAPPDATA%\hermes como candidato moderno.
            Add-SabasHermesHomeCandidate -Path (Join-Path $env:LOCALAPPDATA 'hermes') -Source 'Windows LOCALAPPDATA default'
        }
        else {
            # Conserva un equivalente cuando LOCALAPPDATA no está definido.
            Add-SabasHermesHomeCandidate -Path (Join-Path $HOME 'AppData\Local\hermes') -Source 'Windows LOCALAPPDATA fallback'
        }
        # Añade ~/.hermes como compatibilidad con instalaciones/versiones Windows heredadas.
        Add-SabasHermesHomeCandidate -Path (Join-Path $HOME '.hermes') -Source 'Windows legacy ~/.hermes fallback'
    }
    else {
        # En POSIX el layout estándar es ~/.hermes.
        Add-SabasHermesHomeCandidate -Path (Join-Path $HOME '.hermes') -Source 'POSIX default'
    }
    # Usa el modo debug de discovery para elegir el candidato que Hermes afirma escanear realmente.
    if (($null -ne $HermesExecutable) -and ($Candidates.Count -gt 0)) {
        # Conserva el estado previo de debug.
        $PreviousPluginsDebug = $env:HERMES_PLUGINS_DEBUG
        # Evita que un fallo de versiones antiguas bloquee los fallbacks.
        try {
            # Activa el diagnóstico oficial de discovery.
            $env:HERMES_PLUGINS_DEBUG = '1'
            # Ejecuta discovery capturando stdout/stderr como datos y activando debug solo durante esta llamada.
            $DiscoveryResult = Invoke-SabasNativeCapture -Command 'hermes' -Arguments @('plugins', 'list') -EnvironmentVariables @{ HERMES_PLUGINS_DEBUG = '1' }
            # Une y normaliza separadores para comparar rutas Windows/POSIX.
            $DiscoveryText = (((@($DiscoveryResult.Lines) | ForEach-Object { Remove-SabasAnsi ([string]$_) }) -join [Environment]::NewLine).Replace([char]92, [char]47)).ToLowerInvariant()
            # Busca qué home candidato aparece realmente como ruta de plugins escaneada.
            foreach ($Candidate in $Candidates) {
                # Normaliza el candidato sin exigir que el directorio exista todavía.
                $CandidateNormalized = ([string]$Candidate.Path).Replace([char]92, [char]47).TrimEnd('/').ToLowerInvariant()
                # Construye la ruta plugins esperada.
                $CandidatePluginsNormalized = $CandidateNormalized + '/plugins'
                # Si discovery menciona esa ruta, prioriza la evidencia de ejecución sobre el fallback teórico.
                if ($DiscoveryText.Contains($CandidatePluginsNormalized)) {
                    # Registra el origen original más la confirmación por discovery.
                    $script:HermesHomeResolutionSource = ([string]$Candidate.Source) + ' + HERMES_PLUGINS_DEBUG confirmation'
                    # Devuelve el home realmente escaneado.
                    return [string]$Candidate.Path
                }
            }
        }
        catch {
            # Continúa con los candidatos; el comando debug no está garantizado en releases antiguas.
        }
        finally {
            # Restaura el valor previo exactamente.
            if ($null -eq $PreviousPluginsDebug) { Remove-Item Env:HERMES_PLUGINS_DEBUG -ErrorAction SilentlyContinue }
            else { $env:HERMES_PLUGINS_DEBUG = $PreviousPluginsDebug }
        }
    }
    # Falla únicamente si ni siquiera puede construir un home razonable.
    if ($Candidates.Count -eq 0) { throw 'Unable to resolve any Hermes home candidate.' }
    # Conserva el origen del primer candidato de mayor confianza.
    $script:HermesHomeResolutionSource = [string]$Candidates[0].Source
    # Devuelve la mejor ruta disponible.
    return [string]$Candidates[0].Path
}

# Inicializa la etiqueta de resolución para diagnóstico.
$script:HermesHomeResolutionSource = 'not resolved'
# Resuelve el home efectivo de Hermes antes de construir destinos.
$HermesHome = Resolve-SabasHermesHome
# Define la ubicación personal estándar de skills de Codex.
$CodexSkillsTarget = Join-Path $HOME '.agents\skills'
# Define la ubicación de skills del perfil Hermes realmente activo.
$HermesSkillsTarget = Join-Path $HermesHome 'skills'

# Solicita el destino cuando el usuario no lo proporcionó por parámetro.
if ([string]::IsNullOrWhiteSpace($Target)) {
    # Muestra el encabezado del selector interactivo.
    Write-Host ''
    # Explica las opciones disponibles.
    Write-Host 'Selecciona dónde instalar Sabas Secure Development V0.5.4:'
    # Muestra la opción Codex.
    Write-Host '  1) Codex'
    # Muestra la opción Hermes.
    Write-Host '  2) Hermes'
    # Muestra la opción combinada recomendada cuando se usan ambos agentes.
    Write-Host '  3) Codex + Hermes'
    # Lee la elección del usuario.
    $TargetChoice = Read-Host 'Opción [1-3]'
    # Convierte la opción numérica en el valor validado interno.
    switch ($TargetChoice) {
        # Selecciona Codex.
        '1' { $Target = 'Codex' }
        # Selecciona Hermes.
        '2' { $Target = 'Hermes' }
        # Selecciona ambos agentes.
        '3' { $Target = 'Both' }
        # Rechaza cualquier entrada distinta para no instalar en un destino inesperado.
        default { throw 'Invalid target selection. Use 1, 2 or 3.' }
    }
}
# Informa del destino efectivo antes de realizar cambios.
Write-Host "Installation target: $Target"
# Informa del HERMES_HOME resuelto cuando Hermes forma parte del destino.
if (($Target -eq 'Hermes') -or ($Target -eq 'Both')) {
    # Muestra ruta y mecanismo de resolución para facilitar soporte sin exponer secretos.
    Write-Host "Hermes home resolved: $HermesHome [$script:HermesHomeResolutionSource]"
}

# Selecciona Python 3 para validación, clasificación y hooks.
$ValidationPython = if (Get-Command py -ErrorAction SilentlyContinue) { 'py' } elseif (Get-Command python -ErrorAction SilentlyContinue) { 'python' } else { $null }
# Detiene si Python 3 no está disponible.
if ([string]::IsNullOrWhiteSpace($ValidationPython)) {
    # Explica el requisito exacto.
    throw 'Python 3 is required to install Sabas Secure Development V0.5.4 safely.'
}
# Define el validador determinista incluido en la skill principal.
$BundleValidator = Join-Path $SkillsSource 'sabas-secure-qa\scripts\validate_bundle.py'
# Ejecuta el validador con el launcher adecuado.
if ($ValidationPython -eq 'py') {
    # Fuerza Python 3 en Windows mediante py.exe.
    & py -3 $BundleValidator
}
else {
    # Usa python directamente cuando py.exe no existe.
    & python $BundleValidator
}
# Comprueba que la validación de integridad terminó correctamente.
if ($LASTEXITCODE -ne 0) {
    # Detiene antes de copiar componentes cuando el bundle fue modificado o está incompleto.
    throw 'Bundle validation failed. No installation changes were applied after validation.'
}
# Confirma la verificación de integridad.
Write-Host 'Bundle integrity validation: PASS'
# Crea la carpeta de backup solo después de superar todos los preflight que no modifican los agentes.
New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null

# Define las tres skills propias administradas por Sabas Secure Development.
$SkillNames = @('sabas-secure-qa', 'sabas-threat-model', 'sabas-security-bootstrap')
# Inicializa el estado de integración Hermes para el resumen final.
$script:HermesIntegrationStatus = 'NOT_SELECTED'
# Inicializa el estado de las skills externas para distinguir ausencia solicitada de fallo real.
$script:ExternalSkillsStatus = 'NOT_REQUESTED'

# Instala una skill propia en un árbol de skills concreto conservando backup.
function Install-SabasOwnedSkill {
    # Declara los argumentos de la función.
    param(
        # Recibe el nombre exacto de la skill.
        [Parameter(Mandatory = $true)][string]$SkillName,
        # Recibe la carpeta de destino del agente.
        [Parameter(Mandatory = $true)][string]$SkillsTarget,
        # Recibe una etiqueta para mensajes y backups.
        [Parameter(Mandatory = $true)][string]$PlatformName
    )
    # Construye la ruta fuente de la skill.
    $Source = Join-Path $SkillsSource $SkillName
    # Comprueba que el paquete contenga su SKILL.md obligatorio.
    if (-not (Test-Path (Join-Path $Source 'SKILL.md'))) {
        # Detiene una instalación incompleta.
        throw "Missing SKILL.md for $SkillName in package."
    }
    # Crea el directorio de skills del agente cuando no existe.
    New-Item -ItemType Directory -Force -Path $SkillsTarget | Out-Null
    # Construye la ruta final de la skill.
    $Destination = Join-Path $SkillsTarget $SkillName
    # Conserva una versión previa cuando existe.
    if (Test-Path $Destination) {
        # Crea una carpeta de backup separada por plataforma.
        $PlatformBackup = Join-Path $BackupRoot $PlatformName
        # Crea el directorio de backup necesario.
        New-Item -ItemType Directory -Force -Path $PlatformBackup | Out-Null
        # Copia la versión instalada antes de sustituirla.
        Copy-Item -Recurse -Force -Path $Destination -Destination (Join-Path $PlatformBackup $SkillName)
        # Elimina la versión anterior para evitar mezcla de archivos obsoletos.
        Remove-Item -Recurse -Force -Path $Destination
    }
    # Copia la skill completa.
    Copy-Item -Recurse -Force -Path $Source -Destination $Destination
    # Informa de la instalación concreta.
    Write-Host "Installed [$PlatformName]: $SkillName"
}

# Instala o completa usuario-torpe-qa sin sobrescribir una versión existente del usuario.
function Install-SabasTorpeSupport {
    # Declara los argumentos de la función.
    param(
        # Recibe la carpeta de skills del agente.
        [Parameter(Mandatory = $true)][string]$SkillsTarget,
        # Recibe la etiqueta de plataforma.
        [Parameter(Mandatory = $true)][string]$PlatformName
    )
    # Define el destino de usuario-torpe-qa.
    $TorpeTarget = Join-Path $SkillsTarget 'usuario-torpe-qa'
    # Define los auxiliares que pueden completarse sin tocar SKILL.md existente.
    $SupplementalFiles = @(
        # Incluye perfiles de usuario.
        'references\perfiles.md',
        # Incluye catálogo de pruebas.
        'references\catalogo-pruebas.md',
        # Incluye reglas específicas de WordPress.
        'references\wordpress.md',
        # Incluye plantilla de informe.
        'templates\informe.md',
        # Incluye tabla de incidencias.
        'templates\tabla-incidencias.md',
        # Incluye metadata adicional usada por Codex cuando corresponde.
        'agents\openai.yaml'
    )
    # Instala la copia completa únicamente si no existe la skill.
    if (-not (Test-Path (Join-Path $TorpeTarget 'SKILL.md'))) {
        # Crea la carpeta de skills si todavía no existe.
        New-Item -ItemType Directory -Force -Path $SkillsTarget | Out-Null
        # Copia la skill completa de soporte.
        Copy-Item -Recurse -Force -Path $TorpeSupportSource -Destination $TorpeTarget
        # Informa de la instalación.
        Write-Host "Installed bundled support [$PlatformName]: usuario-torpe-qa"
        # Finaliza esta función.
        return
    }
    # Informa de que el SKILL.md existente será preservado.
    Write-Host "Existing usuario-torpe-qa detected and preserved [$PlatformName]."
    # Recorre auxiliares para completar únicamente archivos faltantes.
    foreach ($SupplementalFile in $SupplementalFiles) {
        # Construye la ruta fuente.
        $SupplementalSource = Join-Path $TorpeSupportSource $SupplementalFile
        # Construye la ruta destino.
        $SupplementalTarget = Join-Path $TorpeTarget $SupplementalFile
        # Copia únicamente cuando el usuario no tiene ese archivo.
        if ((Test-Path $SupplementalSource) -and (-not (Test-Path $SupplementalTarget))) {
            # Crea el directorio padre requerido.
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $SupplementalTarget) | Out-Null
            # Copia el auxiliar faltante.
            Copy-Item -Force -Path $SupplementalSource -Destination $SupplementalTarget
            # Informa del complemento añadido.
            Write-Host "Completed missing usuario-torpe-qa file [$PlatformName]: $SupplementalFile"
        }
    }
}

# Inserta o refresca el bloque administrado Sabas dentro de un AGENTS global de Codex.
function Add-SabasAgentsBlock {
    # Declara la ruta del archivo de instrucciones.
    param([Parameter(Mandatory = $true)][string]$AgentsFile)
    # Define el fragmento administrado.
    $SnippetFile = Join-Path $PackageRoot 'templates\AGENTS.global.md.snippet'
    # Lee el fragmento completo.
    $Snippet = Get-Content -Raw -Path $SnippetFile
    # Inicializa contenido existente.
    $Existing = ''
    # Conserva y lee el archivo cuando ya existe.
    if (Test-Path $AgentsFile) {
        # Lee el contenido actual.
        $Existing = Get-Content -Raw -Path $AgentsFile
        # Copia el archivo original a backup.
        Copy-Item -Force -Path $AgentsFile -Destination (Join-Path $BackupRoot ((Split-Path -Leaf $AgentsFile) + '.bak'))
    }
    # Define el patrón del bloque administrado.
    $ManagedBlockPattern = '(?s)<!-- SABAS-SECURE-DEVELOPMENT:START -->.*?<!-- SABAS-SECURE-DEVELOPMENT:END -->'
    # Actualiza el bloque existente cuando ya está presente.
    if ($Existing -match 'SABAS-SECURE-DEVELOPMENT:START') {
        # Sustituye únicamente el bloque Sabas.
        $Updated = [Regex]::Replace($Existing, $ManagedBlockPattern, $Snippet.Trim())
    }
    else {
        # Añade separación cuando ya existían instrucciones del usuario.
        $Separator = if ([string]::IsNullOrWhiteSpace($Existing)) { '' } else { "`r`n`r`n" }
        # Añade el fragmento al final conservando todo lo anterior.
        $Updated = $Existing + $Separator + $Snippet.Trim() + "`r`n"
    }
    # Crea la carpeta padre cuando es necesario.
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $AgentsFile) | Out-Null
    # Guarda el archivo actualizado.
    Set-Content -Path $AgentsFile -Value $Updated -Encoding utf8
    # Informa del archivo efectivo actualizado.
    Write-Host "Updated Codex instructions: $AgentsFile"
}

# Convierte objetos JSON de PowerShell 5.1 en hashtables editables de forma recursiva.
function ConvertTo-SabasHashtable {
    # Declara el objeto de entrada.
    param([Parameter(ValueFromPipeline = $true)]$InputObject)
    # Conserva null.
    if ($null -eq $InputObject) { return $null }
    # Convierte objetos JSON con propiedades.
    if ($InputObject -is [System.Management.Automation.PSCustomObject]) {
        # Inicializa el mapa de salida.
        $Result = @{}
        # Recorre propiedades públicas.
        foreach ($Property in $InputObject.PSObject.Properties) {
            # Convierte recursivamente cada valor.
            $Result[$Property.Name] = ConvertTo-SabasHashtable -InputObject $Property.Value
        }
        # Devuelve el mapa normalizado.
        return $Result
    }
    # Convierte arrays manteniendo el orden.
    if (($InputObject -is [System.Collections.IEnumerable]) -and -not ($InputObject -is [string]) -and -not ($InputObject -is [System.Collections.IDictionary])) {
        # Inicializa el array de salida.
        $Items = @()
        # Recorre elementos.
        foreach ($Item in $InputObject) {
            # Añade la conversión recursiva.
            $Items += ,(ConvertTo-SabasHashtable -InputObject $Item)
        }
        # Devuelve el array normalizado.
        return $Items
    }
    # Conserva escalares y diccionarios ya compatibles.
    return $InputObject
}

# Instala el Stop hook de Codex conservando otros hooks definidos por el usuario.
function Install-SabasCodexCompletionHook {
    # Selecciona el comando Python para Windows.
    $WindowsPython = if (Get-Command py -ErrorAction SilentlyContinue) { 'py -3' } elseif (Get-Command python -ErrorAction SilentlyContinue) { 'python' } else { $null }
    # Detiene si no existe Python.
    if ([string]::IsNullOrWhiteSpace($WindowsPython)) { throw 'Python 3 is required for the Codex completion hook.' }
    # Crea la carpeta de hooks de Codex.
    $HooksDirectory = Join-Path $CodexHome 'hooks'
    # Garantiza que la carpeta exista.
    New-Item -ItemType Directory -Force -Path $HooksDirectory | Out-Null
    # Define la ruta fuente del hook.
    $HookSource = Join-Path $PackageRoot 'scripts\SabasSecureStopHook.py'
    # Define la ruta runtime del hook.
    $HookTarget = Join-Path $HooksDirectory 'sabas_secure_stop.py'
    # Conserva el hook previo cuando existe.
    if (Test-Path $HookTarget) { Copy-Item -Force -Path $HookTarget -Destination (Join-Path $BackupRoot 'codex-sabas_secure_stop.py.bak') }
    # Copia la versión V0.5.4.
    Copy-Item -Force -Path $HookSource -Destination $HookTarget
    # Define el archivo de configuración de hooks.
    $HooksFile = Join-Path $CodexHome 'hooks.json'
    # Carga o inicializa la configuración.
    if (Test-Path $HooksFile) {
        # Conserva una copia exacta.
        Copy-Item -Force -Path $HooksFile -Destination (Join-Path $BackupRoot 'codex-hooks.json.bak')
        # Lee el JSON existente.
        $RawHooksConfig = Get-Content -Raw -Path $HooksFile
        # Parsea un objeto vacío cuando el archivo está vacío.
        $ParsedHooksConfig = if ([string]::IsNullOrWhiteSpace($RawHooksConfig)) { @{} } else { $RawHooksConfig | ConvertFrom-Json }
        # Convierte el objeto en mapa editable.
        $HooksConfig = ConvertTo-SabasHashtable -InputObject $ParsedHooksConfig
    }
    else {
        # Inicializa una configuración vacía.
        $HooksConfig = @{}
    }
    # Rechaza formatos raíz inesperados.
    if (-not ($HooksConfig -is [System.Collections.IDictionary])) { throw 'Codex hooks.json root must be a JSON object.' }
    # Añade descripción cuando falta.
    if (-not $HooksConfig.ContainsKey('description')) { $HooksConfig['description'] = 'Codex lifecycle hooks including Sabas Secure Development.' }
    # Crea la sección hooks cuando falta.
    if (-not $HooksConfig.ContainsKey('hooks')) { $HooksConfig['hooks'] = @{} }
    # Rechaza una sección hooks incompatible.
    if (-not ($HooksConfig['hooks'] -is [System.Collections.IDictionary])) { throw 'Codex hooks.json hooks property must be a JSON object.' }
    # Obtiene el mapa de eventos.
    $Events = $HooksConfig['hooks']
    # Conserva entradas Stop existentes.
    $StopEntries = if ($Events.ContainsKey('Stop')) { @($Events['Stop']) } else { @() }
    # Elimina únicamente una versión Sabas anterior para mantener idempotencia.
    $FilteredEntries = @($StopEntries | Where-Object { (($_ | ConvertTo-Json -Depth 20) -notmatch 'sabas_secure_stop\.py') })
    # Construye el comando Windows con ruta entre comillas.
    $WindowsHookCommand = $WindowsPython + ' "' + $HookTarget + '"'
    # Define la entrada Sabas de Stop.
    $SabasEntry = @{
        # Define sus handlers.
        hooks = @(
            # Define un handler síncrono de comando.
            @{
                # Usa el tipo de handler soportado.
                type = 'command'
                # Define el comando POSIX.
                command = 'python3 "${CODEX_HOME:-$HOME/.codex}/hooks/sabas_secure_stop.py"'
                # Define el comando Windows.
                commandWindows = $WindowsHookCommand
                # Limita la duración.
                timeout = 25
                # Muestra un estado comprensible.
                statusMessage = 'Checking Sabas Secure completion gate'
            }
        )
    }
    # Sustituye únicamente la entrada Sabas conservando las demás.
    $Events['Stop'] = @($FilteredEntries + $SabasEntry)
    # Serializa el JSON completo.
    $HooksJson = $HooksConfig | ConvertTo-Json -Depth 20
    # Define un archivo temporal de escritura segura.
    $HooksTempFile = Join-Path $CodexHome "hooks.json.sabas-tmp-$Timestamp"
    # Escribe primero el archivo temporal.
    Set-Content -Path $HooksTempFile -Value $HooksJson -Encoding utf8
    # Copia el temporal sobre el destino.
    Copy-Item -Force -Path $HooksTempFile -Destination $HooksFile
    # Elimina el temporal tras éxito.
    Remove-Item -Force -Path $HooksTempFile
    # Informa de la instalación.
    Write-Host "Installed Codex completion hook: $HooksFile"
    # Recuerda la revisión de confianza requerida por Codex.
    Write-Warning 'Codex requires non-managed hooks to be reviewed/trusted. Open /hooks and review the Sabas Secure Stop hook before trusting it.'
}

# Instala y activa el plugin nativo de Hermes con degradación controlada ante diferencias de versión.
function Install-SabasHermesPlugin {
    # Parte de un estado conservador hasta verificar la integración real.
    $script:HermesIntegrationStatus = 'DEGRADED'
    # Define la fuente auditada incluida en el bundle.
    $HermesPluginSource = Join-Path $PackageRoot 'hermes-plugin\sabas-secure-development'
    # Define el fichero de diagnóstico acumulado de esta ejecución.
    $HermesDiagnosticFile = Join-Path $BackupRoot 'hermes-plugin-diagnostic.txt'
    # Comprueba que el plugin tenga su manifiesto y código.
    if ((-not (Test-Path (Join-Path $HermesPluginSource 'plugin.yaml'))) -or (-not (Test-Path (Join-Path $HermesPluginSource '__init__.py')))) {
        # Un bundle incompleto sí es un fallo local que debe detener la instalación.
        throw 'Hermes plugin files are missing from the bundle.'
    }
    # Compila el Python del plugin antes de copiarlo para detectar sintaxis incompatible.
    $HermesPluginPython = Join-Path $HermesPluginSource '__init__.py'
    # Usa el launcher disponible sin shell intermedio.
    if ($ValidationPython -eq 'py') { & py -3 -m py_compile $HermesPluginPython }
    else { & python -m py_compile $HermesPluginPython }
    # Detiene antes de copiar si el propio plugin no compila.
    if ($LASTEXITCODE -ne 0) { throw 'Hermes plugin Python syntax validation failed.' }
    # Elimina el bytecode temporal generado por py_compile para no modificar el bundle instalado.
    $HermesPluginPycache = Join-Path $HermesPluginSource '__pycache__'
    # Limpia únicamente la caché creada durante esta validación.
    if (Test-Path $HermesPluginPycache) { Remove-Item -Recurse -Force -Path $HermesPluginPycache }
    # Confirma la validación de sintaxis.
    Write-Host 'Hermes plugin Python syntax: PASS'
    # Detecta la CLI de Hermes antes de intentar discovery.
    $HermesCommand = Get-Command hermes -ErrorAction SilentlyContinue
    # Si no existe CLI, copia al home resuelto y conserva una degradación explícita sin abortar skills.
    if ($null -eq $HermesCommand) {
        # Define el directorio de plugins del home resuelto.
        $FallbackPluginsDirectory = Join-Path $HermesHome 'plugins'
        # Define el target del plugin.
        $FallbackPluginTarget = Join-Path $FallbackPluginsDirectory 'sabas-secure-development'
        # Crea el directorio de plugins.
        New-Item -ItemType Directory -Force -Path $FallbackPluginsDirectory | Out-Null
        # Conserva una versión previa antes de reemplazarla.
        if (Test-Path $FallbackPluginTarget) {
            # Guarda backup de la versión previa.
            Copy-Item -Recurse -Force -Path $FallbackPluginTarget -Destination (Join-Path $BackupRoot 'hermes-plugin-before-cli-missing')
            # Elimina únicamente el plugin con este nombre.
            Remove-Item -Recurse -Force -Path $FallbackPluginTarget
        }
        # Copia la versión nueva.
        Copy-Item -Recurse -Force -Path $HermesPluginSource -Destination $FallbackPluginTarget
        # Registra un diagnóstico mínimo.
        @(
            'Sabas Secure Development V0.5.4 - Hermes plugin diagnostic',
            'Hermes integration status: DEGRADED',
            'Reason: Hermes CLI not found in PATH.',
            "Resolved HERMES_HOME: $HermesHome",
            "Resolution source: $script:HermesHomeResolutionSource",
            "Plugin target: $FallbackPluginTarget"
        ) | Set-Content -Path $HermesDiagnosticFile -Encoding utf8
        # Avisa sin truncar la instalación de skills externas.
        Write-Warning "Hermes CLI was not found. Plugin files were copied but could not be enabled. Diagnostic: $HermesDiagnosticFile"
        # Devuelve control al instalador principal.
        return
    }
    # Captura la versión tolerando mensajes informativos en stderr.
    $HermesVersionResult = Invoke-SabasNativeCapture -Command 'hermes' -Arguments @('--version')
    # Conserva el código de salida real.
    $HermesVersionExitCode = [int]$HermesVersionResult.ExitCode
    # Normaliza la versión visible sin depender de su formato exacto.
    $HermesVersionText = ((@($HermesVersionResult.Lines) | ForEach-Object { Remove-SabasAnsi ([string]$_) }) -join ' ').Trim()
    # Usa un marcador claro cuando una versión antigua no implemente --version correctamente.
    if ($HermesVersionExitCode -ne 0) { $HermesVersionText = 'unknown' }
    # Recoge la ayuda de plugins sin tratar stderr como una excepción.
    $PluginsHelpResult = Invoke-SabasNativeCapture -Command 'hermes' -Arguments @('plugins', '-h')
    # Conserva el código de salida sin exigir una versión concreta.
    $PluginsHelpExitCode = [int]$PluginsHelpResult.ExitCode
    # Normaliza la ayuda para diagnóstico y detección de capacidades.
    $PluginsHelpText = ((@($PluginsHelpResult.Lines) | ForEach-Object { Remove-SabasAnsi ([string]$_) }) -join [Environment]::NewLine)
    # Detecta soporte de enable mediante la ayuda real, con fallback a la CLI conocida por versiones anteriores.
    $SupportsPluginEnable = ($PluginsHelpExitCode -eq 0) -and ($PluginsHelpText -match '(?i)\benable\b')
    # Detecta soporte de list mediante la ayuda real.
    $SupportsPluginList = ($PluginsHelpExitCode -eq 0) -and ($PluginsHelpText -match '(?i)\blist\b')
    # Construye candidatos de home para cubrir perfil activo, Windows actual y layout Windows heredado.
    $PluginHomeCandidates = New-Object System.Collections.Generic.List[string]
    # Define un helper local para candidatos únicos.
    function Add-SabasPluginHomeCandidate {
        # Declara la ruta candidata.
        param([string]$Path)
        # Ignora entradas vacías.
        if ([string]::IsNullOrWhiteSpace($Path)) { return }
        # Evita duplicados insensibles a mayúsculas.
        foreach ($ExistingHome in $PluginHomeCandidates) {
            # Sale si ya existe el mismo candidato.
            if ([string]::Equals($ExistingHome, $Path, [System.StringComparison]::OrdinalIgnoreCase)) { return }
        }
        # Añade el candidato al orden de pruebas.
        $PluginHomeCandidates.Add($Path)
    }
    # Prueba primero el home resuelto por preflight.
    Add-SabasPluginHomeCandidate -Path $HermesHome
    # En Windows añade ambos layouts conocidos como fallback de compatibilidad.
    if ($env:OS -eq 'Windows_NT') {
        # Añade el layout nativo actual cuando LOCALAPPDATA existe.
        if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) { Add-SabasPluginHomeCandidate -Path (Join-Path $env:LOCALAPPDATA 'hermes') }
        # Añade el layout histórico POSIX-like usado por algunas versiones/instalaciones.
        Add-SabasPluginHomeCandidate -Path (Join-Path $HOME '.hermes')
    }
    # Añade HERMES_HOME explícito si por algún motivo no quedó primero.
    Add-SabasPluginHomeCandidate -Path $env:HERMES_HOME
    # Inicializa el informe detallado de intentos.
    $DiagnosticLines = New-Object System.Collections.Generic.List[string]
    # Registra cabecera y versión sin leer secretos.
    $DiagnosticLines.Add('Sabas Secure Development V0.5.4 - Hermes plugin diagnostic')
    # Registra versión detectada.
    $DiagnosticLines.Add("Hermes version: $HermesVersionText")
    # Registra home inicial.
    $DiagnosticLines.Add("Initial resolved HERMES_HOME: $HermesHome")
    # Registra el mecanismo de resolución.
    $DiagnosticLines.Add("Resolution source: $script:HermesHomeResolutionSource")
    # Registra capacidades observadas.
    $DiagnosticLines.Add("plugins enable supported by help: $SupportsPluginEnable")
    # Registra capacidad de listado.
    $DiagnosticLines.Add("plugins list supported by help: $SupportsPluginList")
    # Inicializa resultado de discovery.
    $SuccessfulHome = $null
    # Inicializa la última salida debug para detectar plugins oficiales después.
    $LastPluginDebugText = ''
    # Recorre cada home candidato hasta encontrar el que Hermes descubre de verdad.
    foreach ($CandidateHome in $PluginHomeCandidates) {
        # Define la carpeta de plugins candidata.
        $CandidatePluginsDirectory = Join-Path $CandidateHome 'plugins'
        # Define el destino exacto del plugin.
        $CandidatePluginTarget = Join-Path $CandidatePluginsDirectory 'sabas-secure-development'
        # Registra el intento sin contenido sensible.
        $DiagnosticLines.Add('--- discovery attempt ---')
        # Registra el home candidato.
        $DiagnosticLines.Add("Candidate HERMES_HOME: $CandidateHome")
        # Recuerda si el plugin ya existía antes de esta ejecución para no borrar personalizaciones ajenas ante fallo.
        $CandidateExistedBefore = Test-Path $CandidatePluginTarget
        # Crea la carpeta candidata.
        New-Item -ItemType Directory -Force -Path $CandidatePluginsDirectory | Out-Null
        # Inicializa la ruta de backup de este intento.
        $AttemptBackupPath = $null
        # Conserva cualquier versión previa con nombre Sabas antes de actualizarla.
        if ($CandidateExistedBefore) {
            # Crea un nombre de backup portable derivado del índice actual.
            $AttemptBackupName = 'hermes-plugin-attempt-' + $PluginHomeCandidates.IndexOf($CandidateHome)
            # Define la ruta de backup completa.
            $AttemptBackupPath = Join-Path $BackupRoot $AttemptBackupName
            # Copia el plugin existente al backup.
            Copy-Item -Recurse -Force -Path $CandidatePluginTarget -Destination $AttemptBackupPath
            # Elimina la versión previa para evitar restos obsoletos.
            Remove-Item -Recurse -Force -Path $CandidatePluginTarget
        }
        # Copia el plugin nuevo exactamente a un nivel bajo plugins/.
        Copy-Item -Recurse -Force -Path $HermesPluginSource -Destination $CandidatePluginTarget
        # Registra la existencia física de los dos archivos obligatorios.
        $DiagnosticLines.Add("plugin.yaml exists: $(Test-Path (Join-Path $CandidatePluginTarget 'plugin.yaml'))")
        # Registra la existencia de register code.
        $DiagnosticLines.Add("__init__.py exists: $(Test-Path (Join-Path $CandidatePluginTarget '__init__.py'))")
        # Inicializa el resultado de enable como no soportado.
        $EnableExitCode = 127
        # Inicializa texto de enable.
        $EnableText = 'enable not attempted because CLI help did not advertise it'
        # Intenta habilitar primero cuando la CLI anuncia la operación; versiones antiguas pueden ocultar no habilitados en list.
        if ($SupportsPluginEnable) {
            # Ejecuta enable mediante el wrapper compatible con stderr de Windows PowerShell 5.1.
            $EnableResult = Invoke-SabasNativeCapture -Command 'hermes' -Arguments @('plugins', 'enable', 'sabas-secure-development')
            # Conserva inmediatamente el código de salida real.
            $EnableExitCode = [int]$EnableResult.ExitCode
            # Normaliza stdout y stderr como texto de diagnóstico.
            $EnableText = ((@($EnableResult.Lines) | ForEach-Object { Remove-SabasAnsi ([string]$_) }) -join [Environment]::NewLine)
        }
        # Inicializa list como no soportado.
        $PluginDebugExitCode = 127
        # Inicializa el texto debug.
        $PluginDebugText = 'plugins list not attempted because CLI help did not advertise it'
        # Ejecuta discovery solo cuando la CLI anuncia list.
        if ($SupportsPluginList) {
            # Conserva el valor previo del modo debug.
            $PreviousPluginsDebug = $env:HERMES_PLUGINS_DEBUG
            # Garantiza restauración incluso si la versión tiene un bug de plugins.
            try {
                # Ejecuta list con debug temporal sin exponer stderr al motor de errores de PowerShell.
                $PluginDebugResult = Invoke-SabasNativeCapture -Command 'hermes' -Arguments @('plugins', 'list') -EnvironmentVariables @{ HERMES_PLUGINS_DEBUG = '1' }
                # Conserva inmediatamente el código real.
                $PluginDebugExitCode = [int]$PluginDebugResult.ExitCode
                # Normaliza stdout y stderr como texto de diagnóstico.
                $PluginDebugText = ((@($PluginDebugResult.Lines) | ForEach-Object { Remove-SabasAnsi ([string]$_) }) -join [Environment]::NewLine)
            }
            finally {
                # Restaura exactamente el entorno previo.
                if ($null -eq $PreviousPluginsDebug) { Remove-Item Env:HERMES_PLUGINS_DEBUG -ErrorAction SilentlyContinue }
                else { $env:HERMES_PLUGINS_DEBUG = $PreviousPluginsDebug }
            }
        }
        # Conserva la salida más reciente para detectar security-guidance.
        $LastPluginDebugText = $PluginDebugText
        # Inicializa la vista compacta como no disponible; evita depender de tablas Rich que pueden truncar nombres con ….
        $PluginPlainExitCode = 127
        # Inicializa un texto explícito para el diagnóstico.
        $PluginPlainText = 'plugins list --plain --no-bundled not attempted because CLI help did not advertise list'
        # Ejecuta la salida compacta cuando existe list; releases actuales de Hermes recomiendan esta vista para automatización.
        if ($SupportsPluginList) {
            # Captura la salida exacta sin bundled plugins para que el nombre no dependa del ancho de consola.
            $PluginPlainResult = Invoke-SabasNativeCapture -Command 'hermes' -Arguments @('plugins', 'list', '--plain', '--no-bundled')
            # Conserva inmediatamente el código real.
            $PluginPlainExitCode = [int]$PluginPlainResult.ExitCode
            # Normaliza ANSI por si una release futura colorea incluso la vista plain.
            $PluginPlainText = ((@($PluginPlainResult.Lines) | ForEach-Object { Remove-SabasAnsi ([string]$_) }) -join [Environment]::NewLine)
        }
        # Registra resultados completos para soporte, sin abrir config ni .env.
        $DiagnosticLines.Add("plugins enable exit code: $EnableExitCode")
        # Añade salida de enable.
        $DiagnosticLines.Add('--- plugins enable output ---')
        # Añade texto de enable.
        $DiagnosticLines.Add($EnableText)
        # Registra código de la vista compacta.
        $DiagnosticLines.Add("plugins list plain exit code: $PluginPlainExitCode")
        # Añade cabecera de la vista estable para automatización.
        $DiagnosticLines.Add('--- plugins list --plain --no-bundled ---')
        # Añade la salida compacta exacta.
        $DiagnosticLines.Add($PluginPlainText)
        # Registra código de discovery gráfico/debug.
        $DiagnosticLines.Add("plugins list debug exit code: $PluginDebugExitCode")
        # Añade cabecera debug.
        $DiagnosticLines.Add('--- HERMES_PLUGINS_DEBUG=1 plugins list ---')
        # Añade el diagnóstico de discovery.
        $DiagnosticLines.Add($PluginDebugText)
        # Busca el nombre completo y estado enabled en la salida plain, que no depende del ancho de consola.
        $PluginVisiblePlain = ($PluginPlainExitCode -eq 0) -and ($PluginPlainText -match '(?im)^\s*sabas-secure-development\b.*\benabled\b')
        # Mantiene compatibilidad con releases cuya salida debug no trunca el identificador.
        $PluginVisibleDebug = ($PluginDebugExitCode -eq 0) -and ($PluginDebugText -match [Regex]::Escape('sabas-secure-development'))
        # Un enable con código 0 y mensaje inequívoco también demuestra discovery aunque la tabla visual trunque el nombre.
        $PluginEnabledByCommand = ($EnableExitCode -eq 0) -and ($EnableText -match '(?i)(already\s+enabled|enabled\s+sabas-secure-development|plugin\s+[\x27\x22]?sabas-secure-development[\x27\x22]?\s+is\s+already\s+enabled)')
        # Consolida las tres evidencias sin aceptar simples coincidencias truncadas.
        $PluginVisible = $PluginVisiblePlain -or $PluginVisibleDebug -or $PluginEnabledByCommand
        # Registra cómo se tomó la decisión para que futuros cambios de formato sean diagnosticables.
        $DiagnosticLines.Add("plugin visibility evidence: plain=$PluginVisiblePlain debug=$PluginVisibleDebug enable=$PluginEnabledByCommand")
        # Si se ve pero el primer enable falló, reintenta ahora que discovery ha refrescado el catálogo.
        if ($PluginVisible -and $SupportsPluginEnable -and ($EnableExitCode -ne 0)) {
            # Ejecuta un segundo enable tras discovery mediante el mismo wrapper tolerante a stderr.
            $RetryEnableResult = Invoke-SabasNativeCapture -Command 'hermes' -Arguments @('plugins', 'enable', 'sabas-secure-development')
            # Conserva el resultado real.
            $RetryEnableExitCode = [int]$RetryEnableResult.ExitCode
            # Registra el reintento.
            $DiagnosticLines.Add("plugins enable retry exit code: $RetryEnableExitCode")
            # Registra su salida sanitizada.
            $DiagnosticLines.Add((( @($RetryEnableResult.Lines) | ForEach-Object { Remove-SabasAnsi ([string]$_) }) -join [Environment]::NewLine))
            # Sustituye el resultado de enable por el reintento.
            $EnableExitCode = $RetryEnableExitCode
        }
        # Considera activa la integración cuando discovery ve el plugin y enable terminó correctamente.
        if ($PluginVisible -and $SupportsPluginEnable -and ($EnableExitCode -eq 0)) {
            # Conserva el home que realmente funcionó.
            $SuccessfulHome = $CandidateHome
            # Deja de probar rutas alternativas.
            break
        }
        # Retira la copia V0.5.4 del candidato fallido para no dejar un plugin huérfano.
        if (Test-Path $CandidatePluginTarget) { Remove-Item -Recurse -Force -Path $CandidatePluginTarget }
        # Si el candidato ya contenía una versión previa, la restaura exactamente desde el backup.
        if ($CandidateExistedBefore -and (-not [string]::IsNullOrWhiteSpace([string]$AttemptBackupPath)) -and (Test-Path $AttemptBackupPath)) {
            # Restaura el plugin previo porque este home no fue el usado por Hermes.
            Copy-Item -Recurse -Force -Path $AttemptBackupPath -Destination $CandidatePluginTarget
        }
    }
    # Si se confirmó un home activo, retira únicamente copias antiguas del plugin Sabas en homes alternativos cuya propiedad pueda demostrarse.
    if (-not [string]::IsNullOrWhiteSpace([string]$SuccessfulHome)) {
        # Recorre todos los candidatos que no son el home efectivo.
        foreach ($AlternateHome in $PluginHomeCandidates) {
            # Omite el home que Hermes acaba de confirmar.
            if ([string]::Equals($AlternateHome, $SuccessfulHome, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
            # Construye la ruta del posible plugin duplicado.
            $AlternatePluginTarget = Join-Path (Join-Path $AlternateHome 'plugins') 'sabas-secure-development'
            # Continúa cuando no existe ninguna copia alternativa.
            if (-not (Test-Path $AlternatePluginTarget)) { continue }
            # Define archivos que permiten demostrar propiedad sin abrir configuración de usuario.
            $AlternateManifestPath = Join-Path $AlternatePluginTarget 'plugin.yaml'
            # Define el marcador nuevo para copias gestionadas desde V0.5.4.
            $AlternateOwnershipPath = Join-Path $AlternatePluginTarget '.sabas-managed-plugin.json'
            # Define el código para reconocer de forma conservadora copias legacy V0.5.x.
            $AlternateCodePath = Join-Path $AlternatePluginTarget '__init__.py'
            # Inicializa la prueba de propiedad como falsa para preservar cualquier plugin desconocido.
            $AlternateManaged = $false
            # Prioriza el marcador machine-readable cuando existe.
            if (Test-Path $AlternateOwnershipPath) {
                # Intenta validar el JSON sin convertir un archivo corrupto en borrado automático.
                try {
                    # Lee únicamente metadatos de propiedad del propio plugin.
                    $AlternateOwnership = Get-Content -Raw -Path $AlternateOwnershipPath | ConvertFrom-Json
                    # Exige simultáneamente gestor, componente y nombre exactos.
                    $AlternateManaged = ([string]$AlternateOwnership.managed_by -eq 'sabas-secure-development') -and ([string]$AlternateOwnership.component -eq 'hermes-plugin') -and ([string]$AlternateOwnership.plugin_name -eq 'sabas-secure-development')
                }
                catch {
                    # Conserva la copia si el marcador no puede validarse.
                    $AlternateManaged = $false
                }
            }
            # Reconoce copias legacy previas al marcador solo con múltiples firmas Sabas exactas.
            elseif ((Test-Path $AlternateManifestPath) -and (Test-Path $AlternateCodePath)) {
                # Lee el manifiesto del plugin alternativo, no config.yaml ni secretos.
                $AlternateManifestText = Get-Content -Raw -Path $AlternateManifestPath
                # Lee el código únicamente para comprobar marcadores públicos Sabas.
                $AlternateCodeText = Get-Content -Raw -Path $AlternateCodePath
                # Exige nombre, descripción Sabas y dos marcadores de recibo para minimizar falsos positivos.
                $AlternateManaged = ($AlternateManifestText -match '(?m)^name:\s*sabas-secure-development\s*$') -and ($AlternateManifestText -match '(?i)Security guardrails for Hermes Agent') -and ($AlternateCodeText -match 'SABAS_SECURITY_VERDICT:') -and ($AlternateCodeText -match 'SABAS_SECURITY_FINGERPRINT:')
            }
            # Preserva cualquier copia cuya propiedad no pueda probarse de forma fuerte.
            if (-not $AlternateManaged) {
                # Registra la decisión conservadora para soporte.
                $DiagnosticLines.Add("Preserved alternate plugin candidate because Sabas ownership was not proven: $AlternatePluginTarget")
                # Continúa con el siguiente home.
                continue
            }
            # Construye un backup estable antes de retirar el duplicado.
            $StaleBackupName = 'hermes-plugin-stale-' + $PluginHomeCandidates.IndexOf($AlternateHome)
            # Define la ruta de recuperación dentro del backup de esta ejecución.
            $StaleBackupPath = Join-Path $BackupRoot $StaleBackupName
            # Copia íntegramente la versión inactiva antes de eliminarla.
            Copy-Item -Recurse -Force -Path $AlternatePluginTarget -Destination $StaleBackupPath
            # Retira únicamente la copia duplicada del home alternativo.
            Remove-Item -Recurse -Force -Path $AlternatePluginTarget
            # Registra ruta retirada y backup para rollback manual.
            $DiagnosticLines.Add("Removed stale managed Sabas plugin copy: $AlternatePluginTarget ; backup: $StaleBackupPath")
            # Informa sin convertir la limpieza en requisito para el éxito del plugin activo.
            Write-Host "Removed stale managed Hermes plugin copy: $AlternatePluginTarget"
        }
    }
    # Guarda el diagnóstico de todos los intentos antes de configurar capas adicionales.
    $DiagnosticLines | Set-Content -Path $HermesDiagnosticFile -Encoding utf8
    # Si algún home funcionó, actualiza el contexto global para skills externas y mensajes finales.
    if (-not [string]::IsNullOrWhiteSpace($SuccessfulHome)) {
        # Cambia el HERMES_HOME efectivo del instalador al realmente descubierto.
        $script:HermesHome = $SuccessfulHome
        # Recalcula el destino de skills del mismo perfil/home.
        $script:HermesSkillsTarget = Join-Path $SuccessfulHome 'skills'
        # Marca el origen como discovery empírico.
        $script:HermesHomeResolutionSource = 'successful Hermes plugin discovery'
        # Confirma discovery y enable.
        Write-Host "Hermes plugin discovery and enable: PASS [$SuccessfulHome]"
        # Marca la integración de plugin como activa provisionalmente.
        $script:HermesIntegrationStatus = 'ACTIVE'
    }
    else {
        # No aborta: las skills siguen siendo útiles y el diagnóstico permite corregir una versión concreta.
        Write-Warning "Hermes could not fully enable/discover the Sabas plugin on any safe candidate home. Installation will continue in DEGRADED mode. Diagnostic: $HermesDiagnosticFile"
    }
    # Configura verify_on_stop aunque el plugin quede degradado usando captura segura de stderr.
    $VerifyConfigResult = Invoke-SabasNativeCapture -Command 'hermes' -Arguments @('config', 'set', 'agent.verify_on_stop', 'auto')
    # Conserva el resultado real.
    $VerifyConfigExitCode = [int]$VerifyConfigResult.ExitCode
    # Informa de éxito o degradación sin truncar el instalador.
    if ($VerifyConfigExitCode -eq 0) { Write-Host 'Hermes verify_on_stop=auto: PASS' }
    else { Write-Warning 'Hermes does not support or could not persist agent.verify_on_stop=auto.' }
    # Define una instrucción global breve que complementa los hooks deterministas.
    $HermesCodingInstructions = 'For executable changes, use sabas-secure-qa, classify risk R0-R4, never claim unexecuted checks passed, treat confirmed/high-confidence Critical or High findings as blockers, preserve server-side authorization boundaries, and require a current Sabas verdict plus fingerprint for R2+ changes. Run usuario-torpe-qa only in explicitly authorized local/test environments.'
    # Intenta guardar la disciplina de desarrollo mediante la CLI oficial y captura segura.
    $CodingConfigResult = Invoke-SabasNativeCapture -Command 'hermes' -Arguments @('config', 'set', 'agent.coding_instructions', $HermesCodingInstructions)
    # Conserva el código de salida real.
    $CodingConfigExitCode = [int]$CodingConfigResult.ExitCode
    # Informa del resultado.
    if ($CodingConfigExitCode -eq 0) { Write-Host 'Hermes coding instructions: PASS' }
    else { Write-Warning 'Hermes does not support or could not persist agent.coding_instructions.' }
    # Activa adicionalmente el plugin de seguridad oficial de Hermes cuando esta versión lo incorpora.
    if ($LastPluginDebugText -match '(?i)security-guidance') {
        # Solicita su activación explícita porque los plugins generales son opt-in.
        $SecurityGuidanceResult = Invoke-SabasNativeCapture -Command 'hermes' -Arguments @('plugins', 'enable', 'security-guidance')
        # Informa solo cuando la activación fue válida.
        if ([int]$SecurityGuidanceResult.ExitCode -eq 0) { Write-Host 'Hermes built-in security-guidance plugin: ENABLED' }
        else { Write-Warning 'Hermes security-guidance was detected but could not be enabled automatically.' }
    }
    # Si el plugin Sabas está activo pero verify_on_stop no pudo configurarse, rebaja el estado global.
    if (($script:HermesIntegrationStatus -eq 'ACTIVE') -and ($VerifyConfigExitCode -ne 0)) {
        # Conserva el plugin pero comunica que falta una capa relevante.
        $script:HermesIntegrationStatus = 'DEGRADED'
    }
    # Informa de forma inequívoca del estado final de Hermes.
    Write-Host "Hermes security integration status: $script:HermesIntegrationStatus"
    # Mantiene siempre el diagnóstico como evidencia de la instalación real.
    Write-Host "Hermes diagnostic: $HermesDiagnosticFile"
}

# Instala componentes Codex cuando el destino lo incluye.
if (($Target -eq 'Codex') -or ($Target -eq 'Both')) {
    # Crea CODEX_HOME.
    New-Item -ItemType Directory -Force -Path $CodexHome | Out-Null
    # Instala las skills propias.
    foreach ($SkillName in $SkillNames) { Install-SabasOwnedSkill -SkillName $SkillName -SkillsTarget $CodexSkillsTarget -PlatformName 'Codex' }
    # Instala o preserva usuario-torpe-qa.
    Install-SabasTorpeSupport -SkillsTarget $CodexSkillsTarget -PlatformName 'Codex'
    # Actualiza instrucciones globales únicamente cuando se solicitó.
    if ($UpdateGlobalAgents) {
        # Actualiza AGENTS.md principal.
        Add-SabasAgentsBlock -AgentsFile (Join-Path $CodexHome 'AGENTS.md')
        # Define el override que Codex prioriza cuando existe.
        $OverrideFile = Join-Path $CodexHome 'AGENTS.override.md'
        # Refresca también un override no vacío para que el gate siga activo.
        if ((Test-Path $OverrideFile) -and (-not [string]::IsNullOrWhiteSpace((Get-Content -Raw -Path $OverrideFile)))) {
            # Inserta el mismo bloque administrado.
            Add-SabasAgentsBlock -AgentsFile $OverrideFile
        }
    }
    # Instala el hook Stop cuando se solicitó.
    if ($InstallCompletionHook) { Install-SabasCodexCompletionHook }
}

# Instala componentes Hermes cuando el destino lo incluye.
if (($Target -eq 'Hermes') -or ($Target -eq 'Both')) {
    # Crea el HERMES_HOME inicialmente resuelto.
    New-Item -ItemType Directory -Force -Path $HermesHome | Out-Null
    # Conserva el primer target por si el discovery empírico descubre un layout distinto.
    $InitialHermesSkillsTarget = $HermesSkillsTarget
    # Instala las skills propias de forma nativa en el home inicialmente resuelto.
    foreach ($SkillName in $SkillNames) { Install-SabasOwnedSkill -SkillName $SkillName -SkillsTarget $HermesSkillsTarget -PlatformName 'Hermes' }
    # Instala o preserva usuario-torpe-qa dentro de Hermes.
    Install-SabasTorpeSupport -SkillsTarget $HermesSkillsTarget -PlatformName 'Hermes'
    # Instala, valida y habilita el plugin de guardrails; puede corregir el HERMES_HOME efectivo tras discovery real.
    Install-SabasHermesPlugin
    # Si discovery demostró que Hermes usa otro home, replica las skills únicamente en ese home efectivo.
    if (-not [string]::Equals($InitialHermesSkillsTarget, $HermesSkillsTarget, [System.StringComparison]::OrdinalIgnoreCase)) {
        # Informa de la autocorrección de layout.
        Write-Host "Hermes home auto-corrected after plugin discovery: $HermesHome"
        # Garantiza la carpeta del perfil realmente activo.
        New-Item -ItemType Directory -Force -Path $HermesSkillsTarget | Out-Null
        # Instala las tres skills propias en el home confirmado.
        foreach ($SkillName in $SkillNames) { Install-SabasOwnedSkill -SkillName $SkillName -SkillsTarget $HermesSkillsTarget -PlatformName 'Hermes-confirmed' }
        # Instala/preserva usuario-torpe-qa en el mismo home confirmado.
        Install-SabasTorpeSupport -SkillsTarget $HermesSkillsTarget -PlatformName 'Hermes-confirmed'
    }
}

# Instala skills externas defensivas en los mismos agentes seleccionados cuando se solicita.
if ($InstallExternalSkills) {
    # Marca que esta capa fue solicitada explícitamente.
    $script:ExternalSkillsStatus = 'REQUESTED'
    # Define el instalador externo V0.5.4.
    $ExternalInstaller = Join-Path $PSScriptRoot 'Install-ExternalSecuritySkills.ps1'
    # Aísla fallos de red/upstream para no deshacer ni truncar el núcleo ya instalado.
    try {
        # Ejecuta una única descarga y copia a los destinos correspondientes usando el HERMES_HOME ya confirmado cuando aplica.
        & $ExternalInstaller -Profile $ExternalProfile -Target $Target -HermesHomeOverride $HermesHome -Force:$Force
        # Marca éxito únicamente si el script terminó sin excepción.
        $script:ExternalSkillsStatus = 'INSTALLED'
    }
    catch {
        # Marca fallo visible sin fingir que las skills externas están presentes.
        $script:ExternalSkillsStatus = 'FAILED'
        # Informa de la causa concreta y continúa con self-tests/final status.
        Write-Warning ("External defensive skills could not be completed: " + $_.Exception.Message)
    }
}

# Ejecuta el test local del bundle después de la instalación cuando Python está disponible.
$SelfTest = Join-Path $PackageRoot 'tests\test_sabas_secure_dev.py'
# Ejecuta la batería ligera sin modificar los agentes instalados.
if (Test-Path $SelfTest) {
    # Usa py.exe cuando fue el intérprete seleccionado.
    if ($ValidationPython -eq 'py') { & py -3 $SelfTest --bundle $PackageRoot }
    # Usa python directo en el resto de plataformas.
    else { & python $SelfTest --bundle $PackageRoot }
    # Detiene si una regresión interna falla.
    if ($LASTEXITCODE -ne 0) { throw 'Sabas Secure Development self-test failed after installation.' }
}

# Informa del directorio de backups de la ejecución.
Write-Host "Backup directory: $BackupRoot"
# Informa del CODEX_HOME efectivo cuando procede.
if (($Target -eq 'Codex') -or ($Target -eq 'Both')) { Write-Host "CODEX_HOME used: $CodexHome" }
# Informa del HERMES_HOME efectivo cuando procede.
if (($Target -eq 'Hermes') -or ($Target -eq 'Both')) {
    # Muestra el home exacto y el estado de la capa Hermes.
    Write-Host "HERMES_HOME used: $HermesHome"
    # Muestra ACTIVE/DEGRADED para evitar falsos positivos de instalación.
    Write-Host "Hermes integration: $script:HermesIntegrationStatus"
}
# Informa del estado de skills externas cuando fueron solicitadas.
if ($InstallExternalSkills) { Write-Host "External defensive skills: $script:ExternalSkillsStatus" }
# Confirma la finalización del instalador principal aunque una integración opcional haya quedado degradada.
Write-Host "Sabas Secure Development V0.5.4 installation complete for target: $Target"
# Recomienda recargar los agentes para refrescar discovery.
Write-Host 'Restart/reload Codex and/or Hermes so every skill and plugin is rediscovered.'
