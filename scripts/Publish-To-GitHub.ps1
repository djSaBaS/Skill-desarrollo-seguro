# Declara parámetros para publicar este bundle en un repositorio nuevo mediante GitHub CLI.
param(
    # Define el nombre del repositorio a crear.
    [string]$RepositoryName = 'sabas-secure-development',
    # Permite elegir visibilidad sin asumir que el código debe ser público.
    [ValidateSet('private', 'public')]
    [string]$Visibility = 'private'
)

# Activa comprobaciones estrictas.
Set-StrictMode -Version Latest
# Convierte errores en fallos terminantes.
$ErrorActionPreference = 'Stop'

# Ejecuta Git/GitHub CLI decidiendo por exit code y no por texto escrito en stderr.
function Invoke-SabasPublishNativeCapture {
    # Declara comando y argumentos separados.
    param(
        # Recibe `git` o `gh`.
        [Parameter(Mandatory = $true)][string]$Command,
        # Recibe argumentos ya tokenizados.
        [string[]]$Arguments = @()
    )
    # Conserva la política estricta del publicador.
    $PreviousPublishErrorActionPreference = $ErrorActionPreference
    # Garantiza restauración tras cualquier resultado nativo.
    try {
        # Evita NativeCommandError terminante por warnings/progreso legítimo en Windows PowerShell 5.1.
        $ErrorActionPreference = 'Continue'
        # Resuelve el ejecutable mediante PATH.
        $ResolvedPublishCommand = Get-Command $Command -ErrorAction Stop
        # Usa su ruta física para evitar diferencias de invocación de CommandInfo en Windows PowerShell 5.1.
        $ResolvedPublishPath = if (-not [string]::IsNullOrWhiteSpace([string]$ResolvedPublishCommand.Source)) { [string]$ResolvedPublishCommand.Source } else { $Command }
        # Captura stdout y stderr únicamente dentro del wrapper.
        $PublishOutput = @(& $ResolvedPublishPath @Arguments 2>&1)
        # Conserva el exit code real inmediatamente.
        $PublishExitCode = $LASTEXITCODE
        # Convierte ambas corrientes a líneas de texto.
        $PublishLines = @(foreach ($PublishItem in $PublishOutput) {
            # Extrae stderr encapsulado como ErrorRecord en Windows PowerShell 5.1.
            if ($PublishItem -is [System.Management.Automation.ErrorRecord]) {
                # Obtiene el mensaje original.
                $PublishMessage = [string]$PublishItem.Exception.Message
                # Usa la representación completa como fallback.
                if ([string]::IsNullOrWhiteSpace($PublishMessage)) { $PublishMessage = [string]$PublishItem }
                # Emite la línea recuperada.
                $PublishMessage
            }
            else {
                # Conserva stdout normal.
                [string]$PublishItem
            }
        })
        # Devuelve resultado estructurado.
        return [PSCustomObject]@{ ExitCode = [int]$PublishExitCode; Lines = $PublishLines; Text = ($PublishLines -join [Environment]::NewLine) }
    }
    catch {
        # Convierte un fallo de lanzamiento en resultado controlado.
        $PublishFailure = [string]$_.Exception.Message
        # Devuelve código 127 para distinguirlo de un error del propio comando.
        return [PSCustomObject]@{ ExitCode = 127; Lines = @($PublishFailure); Text = $PublishFailure }
    }
    finally {
        # Restaura la política estricta del script.
        $ErrorActionPreference = $PreviousPublishErrorActionPreference
    }
}
# Resuelve la raíz del bundle.
$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
# Exige Git.
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'Git is required.' }
# Exige GitHub CLI porque es la herramienta que puede crear el repositorio con tu sesión local.
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw 'GitHub CLI (gh) is required. Install it and run gh auth login first.' }
# Comprueba que exista una sesión GitHub válida tolerando mensajes informativos en stderr.
$AuthResult = Invoke-SabasPublishNativeCapture -Command 'gh' -Arguments @('auth', 'status')
# Detiene si no hay autenticación correcta.
if ([int]$AuthResult.ExitCode -ne 0) { throw 'GitHub CLI is not authenticated. Run: gh auth login' }
# Obtiene el login autenticado sin guardar tokens ni credenciales.
$OwnerResult = Invoke-SabasPublishNativeCapture -Command 'gh' -Arguments @('api', 'user', '--jq', '.login')
# Selecciona la última línea no vacía como login.
$Owner = [string](@($OwnerResult.Lines | ForEach-Object { ([string]$_).Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Last 1))
# Exige un owner no vacío y una respuesta válida.
if (([int]$OwnerResult.ExitCode -ne 0) -or [string]::IsNullOrWhiteSpace($Owner)) { throw 'Unable to determine the authenticated GitHub owner.' }
# Obtiene el identificador numérico público de GitHub para poder construir un correo noreply local si Git no tiene identidad configurada.
$OwnerIdResult = Invoke-SabasPublishNativeCapture -Command 'gh' -Arguments @('api', 'user', '--jq', '.id')
# Normaliza el ID únicamente cuando la API respondió correctamente.
$OwnerId = if ([int]$OwnerIdResult.ExitCode -eq 0) { [string](@($OwnerIdResult.Lines | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ -match '^\d+$' } | Select-Object -Last 1)) } else { '' }
# Construye el nombre completo del repositorio.
$RepositoryFullName = "$Owner/$RepositoryName"
# Comprueba que el destino no exista para cumplir la intención de crear un repositorio nuevo.
$ExistingRepoResult = Invoke-SabasPublishNativeCapture -Command 'gh' -Arguments @('repo', 'view', $RepositoryFullName, '--json', 'name')
# Rechaza sobreescribir un repositorio preexistente.
if ([int]$ExistingRepoResult.ExitCode -eq 0) { throw "Repository already exists: $RepositoryFullName" }
# Inicializa Git cuando el paquete todavía no es un checkout.
if (-not (Test-Path (Join-Path $RepositoryRoot '.git'))) {
    # Crea el repositorio local mediante captura segura.
    $GitInitResult = Invoke-SabasPublishNativeCapture -Command 'git' -Arguments @('-C', $RepositoryRoot, 'init')
    # Comprueba el init.
    if ([int]$GitInitResult.ExitCode -ne 0) { throw ('git init failed. ' + $GitInitResult.Text) }
    # Crea/renombra la rama principal a main.
    $GitBranchResult = Invoke-SabasPublishNativeCapture -Command 'git' -Arguments @('-C', $RepositoryRoot, 'branch', '-M', 'main')
    # Comprueba el cambio de rama.
    if ([int]$GitBranchResult.ExitCode -ne 0) { throw ('Unable to set main branch. ' + $GitBranchResult.Text) }
}
# Lee el nombre Git efectivo sin modificar configuración global.
$GitUserNameResult = Invoke-SabasPublishNativeCapture -Command 'git' -Arguments @('-C', $RepositoryRoot, 'config', 'user.name')
# Normaliza el valor cuando existe.
$GitUserName = if ([int]$GitUserNameResult.ExitCode -eq 0) { ($GitUserNameResult.Lines -join '').Trim() } else { '' }
# Define una identidad local basada en el login autenticado cuando Git no tiene nombre configurado.
if ([string]::IsNullOrWhiteSpace($GitUserName)) {
    # Configura únicamente este repositorio.
    $GitNameSetResult = Invoke-SabasPublishNativeCapture -Command 'git' -Arguments @('-C', $RepositoryRoot, 'config', 'user.name', $Owner)
    # Detiene si Git rechazó la configuración local.
    if ([int]$GitNameSetResult.ExitCode -ne 0) { throw ('Unable to configure local git user.name. ' + $GitNameSetResult.Text) }
}
# Lee el correo Git efectivo sin exponer credenciales.
$GitUserEmailResult = Invoke-SabasPublishNativeCapture -Command 'git' -Arguments @('-C', $RepositoryRoot, 'config', 'user.email')
# Normaliza el valor cuando existe.
$GitUserEmail = if ([int]$GitUserEmailResult.ExitCode -eq 0) { ($GitUserEmailResult.Lines -join '').Trim() } else { '' }
# Usa el formato noreply de GitHub cuando no existe correo configurado.
if ([string]::IsNullOrWhiteSpace($GitUserEmail)) {
    # Construye un correo noreply únicamente con identificadores públicos de la cuenta autenticada.
    $NoreplyEmail = if ([string]::IsNullOrWhiteSpace($OwnerId)) { "$Owner@users.noreply.github.com" } else { "$OwnerId+$Owner@users.noreply.github.com" }
    # Configura el correo solo dentro de este repositorio.
    $GitEmailSetResult = Invoke-SabasPublishNativeCapture -Command 'git' -Arguments @('-C', $RepositoryRoot, 'config', 'user.email', $NoreplyEmail)
    # Detiene si Git rechazó la configuración local.
    if ([int]$GitEmailSetResult.ExitCode -ne 0) { throw ('Unable to configure local git user.email. ' + $GitEmailSetResult.Text) }
}
# Define exactamente las rutas administradas que se publicarán.
$ManagedPaths = @(
    # Publica documentación principal.
    'README.md',
    # Publica guía de instalación.
    'INSTALL.md',
    # Publica historial de cambios.
    'CHANGELOG.md',
    # Publica documentación de skills externas.
    'EXTERNAL-SKILLS.md',
    # Publica el lockfile de supply chain.
    'EXTERNAL-SKILLS.lock.json',
    # Publica atribuciones.
    'THIRD_PARTY.md',
    'SECURITY.md',
    '.gitignore',
    '.github',
    # Publica guía de VS Code.
    'VSCODE.md',
    # Publica el manifiesto de integridad.
    'MANIFEST.sha256',
    # Publica metadata Codex.
    '.codex-plugin',
    # Publica scripts instaladores y guardrails.
    'scripts',
    # Publica las skills Sabas.
    'skills',
    # Publica usuario-torpe-qa y sus auxiliares.
    'support-skills',
    # Publica plantillas.
    'templates',
    # Publica el plugin Hermes.
    'hermes-plugin',
    # Publica tests de regresión.
    'tests'
)
# Añade al índice únicamente las rutas explícitas del producto.
foreach ($ManagedPath in $ManagedPaths) {
    # Comprueba que la ruta exista antes de intentar stagearla.
    if (Test-Path (Join-Path $RepositoryRoot $ManagedPath)) {
        # Stagea exclusivamente esa ruta.
        $GitAddResult = Invoke-SabasPublishNativeCapture -Command 'git' -Arguments @('-C', $RepositoryRoot, 'add', '--', $ManagedPath)
        # Detiene si Git no pudo añadirla.
        if ([int]$GitAddResult.ExitCode -ne 0) { throw ("git add failed for: $ManagedPath. " + $GitAddResult.Text) }
    }
}
# Comprueba si hay cambios preparados.
$StagedResult = Invoke-SabasPublishNativeCapture -Command 'git' -Arguments @('-C', $RepositoryRoot, 'diff', '--cached', '--name-only')
# Usa únicamente las líneas capturadas cuando Git respondió correctamente.
$StagedNames = if ([int]$StagedResult.ExitCode -eq 0) { @($StagedResult.Lines) } else { @() }
# Crea el commit inicial únicamente cuando existe contenido preparado.
if (-not [string]::IsNullOrWhiteSpace(($StagedNames -join "`n"))) {
    # Crea el commit inicial del producto.
    $GitCommitResult = Invoke-SabasPublishNativeCapture -Command 'git' -Arguments @('-C', $RepositoryRoot, 'commit', '-m', 'Sabas Secure Development V0.5.4')
    # Detiene si el commit falla.
    if ([int]$GitCommitResult.ExitCode -ne 0) { throw ('Unable to create the initial commit. ' + $GitCommitResult.Text) }
}
# Selecciona el flag de visibilidad solicitado.
$VisibilityFlag = if ($Visibility -eq 'public') { '--public' } else { '--private' }
# Crea y publica el repositorio con argumentos separados y captura segura.
$GitHubCreateResult = Invoke-SabasPublishNativeCapture -Command 'gh' -Arguments @('repo', 'create', $RepositoryFullName, $VisibilityFlag, '--source', $RepositoryRoot, '--remote', 'origin', '--push', '--description', 'Secure-by-default development guardrails for Codex and Hermes, including usuario-torpe-qa.')
# Comprueba la publicación por exit code real.
if ([int]$GitHubCreateResult.ExitCode -ne 0) { throw ('GitHub repository creation/push failed. ' + $GitHubCreateResult.Text) }
# Informa de la URL final sin exponer credenciales.
Write-Host "Published: https://github.com/$RepositoryFullName"
