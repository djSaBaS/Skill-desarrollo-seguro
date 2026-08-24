# Declara parámetros opcionales para guardar el diagnóstico en un archivo concreto.
param(
    # Permite elegir la ruta de salida; si se omite solo se muestra por pantalla.
    [string]$OutputPath
)

# Activa comprobaciones estrictas para detectar fallos de scripting.
Set-StrictMode -Version Latest
# Convierte errores PowerShell no terminantes en excepciones controlables.
$ErrorActionPreference = 'Stop'

# Elimina secuencias ANSI de la salida de Hermes para facilitar lectura y comparación.
function Remove-SabasAnsi {
    # Declara el texto de entrada.
    param([AllowNull()][string]$Text)
    # Devuelve vacío para valores nulos.
    if ($null -eq $Text) { return '' }
    # Elimina códigos CSI usados por Rich/Colorama.
    return [Regex]::Replace($Text, '\x1B\[[0-?]*[ -/]*[@-~]', '')
}

# Ejecuta un comando Hermes y devuelve salida limpia más código sin asumir que el subcomando exista.
function Invoke-SabasHermesProbe {
    # Recibe argumentos separados para evitar shell intermedio.
    param([string[]]$Arguments)
    # Conserva la política estricta del script para restaurarla al terminar.
    $PreviousProbeErrorActionPreference = $ErrorActionPreference
    # Conserva la codificación nativa de PowerShell.
    $PreviousProbeOutputEncoding = $OutputEncoding
    # Inicializa el snapshot de Console.OutputEncoding.
    $PreviousProbeConsoleEncoding = $null
    # Registra si fue posible capturar la codificación de consola.
    $ProbeConsoleEncodingCaptured = $false
    # Garantiza restauración aunque Hermes emita stderr informativo.
    try {
        # Windows PowerShell 5.1 transforma stderr redirigido en ErrorRecord; Continue evita que sea terminante.
        $ErrorActionPreference = 'Continue'
        # Intenta decodificar correctamente CLIs UTF-8 modernas.
        try {
            # Conserva la codificación previa.
            $PreviousProbeConsoleEncoding = [Console]::OutputEncoding
            # Marca la restauración como disponible.
            $ProbeConsoleEncodingCaptured = $true
            # Construye UTF-8 sin BOM.
            $ProbeUtf8 = New-Object System.Text.UTF8Encoding($false)
            # Aplica UTF-8 durante la llamada.
            [Console]::OutputEncoding = $ProbeUtf8
            # Aplica también la codificación nativa de PowerShell.
            $OutputEncoding = $ProbeUtf8
        }
        catch {
            # Continúa con la codificación del host cuando no puede modificarse.
        }
        # Ejecuta Hermes con los argumentos dados capturando stdout y stderr como datos.
        $Output = @(& hermes @Arguments 2>&1)
        # Conserva el código nativo antes de cualquier otro comando.
        $ExitCode = $LASTEXITCODE
        # Normaliza ErrorRecord nativos y stdout a strings.
        $OutputLines = @(foreach ($OutputItem in $Output) {
            # Extrae el mensaje original cuando stderr fue encapsulado por PowerShell.
            if ($OutputItem -is [System.Management.Automation.ErrorRecord]) {
                # Prioriza el mensaje nativo.
                $ProbeMessage = [string]$OutputItem.Exception.Message
                # Usa la representación completa como fallback.
                if ([string]::IsNullOrWhiteSpace($ProbeMessage)) { $ProbeMessage = [string]$OutputItem }
                # Emite la línea recuperada.
                $ProbeMessage
            }
            else {
                # Conserva stdout ordinario.
                [string]$OutputItem
            }
        })
        # Normaliza salida y ANSI.
        $Text = (($OutputLines | ForEach-Object { Remove-SabasAnsi ([string]$_) }) -join [Environment]::NewLine).Trim()
        # Devuelve un objeto estructurado.
        return [PSCustomObject]@{ ExitCode = $ExitCode; Text = $Text }
    }
    finally {
        # Restaura la codificación nativa de PowerShell.
        $OutputEncoding = $PreviousProbeOutputEncoding
        # Restaura Console.OutputEncoding cuando se pudo capturar.
        if ($ProbeConsoleEncodingCaptured) { try { [Console]::OutputEncoding = $PreviousProbeConsoleEncoding } catch { } }
        # Restaura la política global del script.
        $ErrorActionPreference = $PreviousProbeErrorActionPreference
    }
}

# Define una colección mutable para el informe.
$Report = New-Object System.Collections.Generic.List[string]
# Añade el encabezado del diagnóstico.
$Report.Add('Sabas Secure Development V0.5.4 - Hermes diagnostic')
# Añade la fecha local para poder correlacionar ejecuciones.
$Report.Add(('Generated: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')))

# Localiza la CLI de Hermes.
$HermesCommand = Get-Command hermes -ErrorAction SilentlyContinue
# Informa y termina con código 2 cuando Hermes no está en PATH.
if ($null -eq $HermesCommand) {
    # Registra el problema principal.
    $Report.Add('Hermes CLI: NOT FOUND')
    # Muestra el diagnóstico disponible.
    $Report | ForEach-Object { Write-Host $_ }
    # Guarda el informe cuando se solicitó.
    if (-not [string]::IsNullOrWhiteSpace($OutputPath)) { $Report | Set-Content -Path $OutputPath -Encoding utf8 }
    # Devuelve un código específico de CLI ausente.
    exit 2
}

# Registra la ruta ejecutable real sin leer credenciales.
$Report.Add(('Hermes executable: ' + $HermesCommand.Source))
# Obtiene la versión instalada.
$VersionProbe = Invoke-SabasHermesProbe -Arguments @('--version')
# Selecciona una representación simple de la versión.
if ($VersionProbe.ExitCode -eq 0) { $VersionDisplay = $VersionProbe.Text } else { $VersionDisplay = 'UNKNOWN' }
# Registra la versión o un marcador de error.
$Report.Add(('Hermes version: ' + $VersionDisplay))

# Obtiene la ayuda real del subsistema plugins para conocer capacidades de esta versión.
$PluginsHelpProbe = Invoke-SabasHermesProbe -Arguments @('plugins', '-h')
# Registra el código de salida de la ayuda.
$Report.Add(('hermes plugins -h exit: ' + $PluginsHelpProbe.ExitCode))
# Registra la ayuda porque no contiene secretos y revela subcomandos disponibles.
$Report.Add('--- plugins help ---')
# Añade el texto de ayuda.
$Report.Add($PluginsHelpProbe.Text)

# Pregunta a Hermes por el config efectivo para identificar el perfil real cuando el comando existe.
$ConfigPathProbe = Invoke-SabasHermesProbe -Arguments @('config', 'path')
# Registra el resultado sin abrir el fichero.
$Report.Add(('hermes config path exit: ' + $ConfigPathProbe.ExitCode))
# Registra únicamente la ruta devuelta por Hermes.
$Report.Add(('hermes config path: ' + $ConfigPathProbe.Text))

# Obtiene los perfiles disponibles; una versión antigua puede devolver usage/error y se conserva como evidencia.
$ProfileProbe = Invoke-SabasHermesProbe -Arguments @('profile', 'list')
# Registra el estado del comando.
$Report.Add(('hermes profile list exit: ' + $ProfileProbe.ExitCode))
# Separa el bloque de perfiles.
$Report.Add('--- profiles ---')
# Añade el listado o mensaje de incompatibilidad.
$Report.Add($ProfileProbe.Text)

# Construye una lista única de homes plausibles sin leer sus configuraciones.
$HomeCandidates = New-Object System.Collections.Generic.List[string]
# Define un helper para añadir candidatos no vacíos sin duplicados.
function Add-SabasDoctorHomeCandidate {
    # Recibe una ruta candidata.
    param([string]$Path)
    # Ignora valores vacíos.
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    # Recorre rutas existentes de la lista.
    foreach ($ExistingHome in $HomeCandidates) {
        # Evita duplicados tolerando mayúsculas/minúsculas.
        if ([string]::Equals($ExistingHome, $Path, [System.StringComparison]::OrdinalIgnoreCase)) { return }
    }
    # Añade la ruta.
    $HomeCandidates.Add($Path)
}

# Extrae el padre de config.yaml cuando `config path` respondió correctamente.
if ($ConfigPathProbe.ExitCode -eq 0) {
    # Recorre líneas por si existe texto auxiliar.
    foreach ($ConfigLine in ($ConfigPathProbe.Text -split "`r?`n")) {
        # Busca una ruta Windows terminada en config YAML.
        if ($ConfigLine.Trim() -match '(?i)([A-Z]:[\\/].*config\.ya?ml)\s*$') {
            # Añade el directorio padre del config efectivo.
            Add-SabasDoctorHomeCandidate -Path (Split-Path -Parent $Matches[1])
        }
        # Busca una ruta POSIX terminada en config YAML.
        elseif ($ConfigLine.Trim() -match '(?i)(/.*config\.ya?ml)\s*$') {
            # Añade el directorio padre del config efectivo.
            Add-SabasDoctorHomeCandidate -Path (Split-Path -Parent $Matches[1])
        }
    }
}
# Añade el override HERMES_HOME si existe.
Add-SabasDoctorHomeCandidate -Path $env:HERMES_HOME
# Añade layouts Windows conocidos.
if ($env:OS -eq 'Windows_NT') {
    # Añade LOCALAPPDATA\hermes cuando está definido.
    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) { Add-SabasDoctorHomeCandidate -Path (Join-Path $env:LOCALAPPDATA 'hermes') }
    # Añade ~/.hermes como layout heredado compatible.
    Add-SabasDoctorHomeCandidate -Path (Join-Path $HOME '.hermes')
}
else {
    # Añade ~/.hermes en POSIX.
    Add-SabasDoctorHomeCandidate -Path (Join-Path $HOME '.hermes')
}

# Separa el inventario de rutas candidatas.
$Report.Add('--- local plugin candidates ---')
# Recorre cada ruta sin abrir config.yaml ni .env.
foreach ($CandidateHome in $HomeCandidates) {
    # Construye el target esperado del plugin Sabas.
    $CandidatePlugin = Join-Path (Join-Path $CandidateHome 'plugins') 'sabas-secure-development'
    # Registra el home candidato.
    $Report.Add(('candidate home: ' + $CandidateHome))
    # Registra si existe el manifiesto.
    $Report.Add(('  plugin.yaml: ' + (Test-Path (Join-Path $CandidatePlugin 'plugin.yaml'))))
    # Registra si existe el código de registro.
    $Report.Add(('  __init__.py: ' + (Test-Path (Join-Path $CandidatePlugin '__init__.py'))))
    # Registra si están las skills principales en el mismo home.
    $Report.Add(('  sabas-secure-qa skill: ' + (Test-Path (Join-Path (Join-Path $CandidateHome 'skills') 'sabas-secure-qa\SKILL.md'))))
}

# Conserva el valor previo del modo debug de plugins.
$PreviousPluginsDebug = $env:HERMES_PLUGINS_DEBUG
# Garantiza restauración del entorno incluso si Hermes tiene un bug.
try {
    # Activa el diagnóstico oficial de discovery.
    $env:HERMES_PLUGINS_DEBUG = '1'
    # Pide a Hermes que enumere plugins y rutas escaneadas.
    $PluginsProbe = Invoke-SabasHermesProbe -Arguments @('plugins', 'list')
}
finally {
    # Restaura el entorno original cuando antes no existía la variable.
    if ($null -eq $PreviousPluginsDebug) { Remove-Item Env:HERMES_PLUGINS_DEBUG -ErrorAction SilentlyContinue }
    # Restaura el valor previo cuando existía.
    else { $env:HERMES_PLUGINS_DEBUG = $PreviousPluginsDebug }
}
# Registra el código de salida.
$Report.Add(('hermes plugins list exit: ' + $PluginsProbe.ExitCode))
# Separa el bloque debug.
$Report.Add('--- HERMES_PLUGINS_DEBUG=1 plugins list ---')
# Añade discovery sin leer configuración ni secretos.
$Report.Add($PluginsProbe.Text)

# Pide también la vista compacta que no trunca nombres por ancho de consola.
$PluginsPlainProbe = Invoke-SabasHermesProbe -Arguments @('plugins', 'list', '--plain', '--no-bundled')
# Registra su código de salida para saber si esta release soporta ambos flags.
$Report.Add(('hermes plugins list --plain --no-bundled exit: ' + $PluginsPlainProbe.ExitCode))
# Separa el bloque compacto.
$Report.Add('--- plugins list --plain --no-bundled ---')
# Añade la vista estable para automatización.
$Report.Add($PluginsPlainProbe.Text)

# Comprueba nombre completo + enabled en la vista compacta.
$SabasVisiblePlain = ($PluginsPlainProbe.ExitCode -eq 0) -and ($PluginsPlainProbe.Text -match '(?im)^\s*sabas-secure-development\b.*\benabled\b')
# Mantiene la tabla debug como fallback para versiones sin los flags plain/no-bundled.
$SabasVisibleDebug = ($PluginsProbe.ExitCode -eq 0) -and ($PluginsProbe.Text -match [Regex]::Escape('sabas-secure-development'))
# Consolida ambas evidencias evitando falsos negativos por elipsis visual.
$SabasVisible = $SabasVisiblePlain -or $SabasVisibleDebug
# Registra el resultado y su fuente.
$Report.Add(('Sabas plugin visible: ' + $SabasVisible + ' [plain=' + $SabasVisiblePlain + '; debug=' + $SabasVisibleDebug + ']'))
# Comprueba si el plugin oficial security-guidance aparece en esta versión.
$SecurityGuidanceVisible = $PluginsProbe.Text -match '(?i)security-guidance'
# Registra la disponibilidad de la capa oficial.
$Report.Add(('Hermes security-guidance visible: ' + $SecurityGuidanceVisible))

# Muestra todas las líneas del informe.
$Report | ForEach-Object { Write-Host $_ }
# Guarda una copia cuando se solicitó.
if (-not [string]::IsNullOrWhiteSpace($OutputPath)) { $Report | Set-Content -Path $OutputPath -Encoding utf8 }
# Devuelve éxito cuando el subsistema plugins pudo listar; la visibilidad Sabas se informa aparte.
if ($PluginsProbe.ExitCode -eq 0) { exit 0 }
# Devuelve código 1 ante un fallo del subsistema plugins.
exit 1
