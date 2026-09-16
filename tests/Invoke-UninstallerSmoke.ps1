# Declara la raiz del bundle como parametro opcional para CI.
param(
    # Usa el padre de tests por defecto.
    [string]$BundleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

# Activa comprobaciones estrictas.
Set-StrictMode -Version Latest
# Convierte errores PowerShell en fallos terminantes.
$ErrorActionPreference = 'Stop'

# Limita esta prueba destructiva a runners efimeros de GitHub Actions.
if (($env:OS -ne 'Windows_NT') -or ($env:GITHUB_ACTIONS -ne 'true')) {
    # Evita tocar instalaciones locales cuando alguien ejecuta el archivo manualmente.
    Write-Host 'UNINSTALLER_SMOKE: SKIP (GitHub Actions Windows only)'
    # Devuelve exito porque la regresion real se valida en CI Windows.
    exit 0
}

# Define las skills propias que el wrapper instala y el desinstalador debe retirar.
$SkillNames = @('sabas-efficient-development', 'sabas-secure-qa', 'sabas-threat-model', 'sabas-security-bootstrap')
# Define una raiz temporal aislada para CODEX_HOME y el hook de prueba.
$TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('sabas-uninstaller-smoke-' + [System.Guid]::NewGuid().ToString('N'))
# Define un CODEX_HOME temporal para no tocar hooks reales.
$FakeCodexHome = Join-Path $TempRoot 'codex-home'
# Define un HERMES_HOME temporal para que All no toque perfiles reales.
$FakeHermesHome = Join-Path $TempRoot 'hermes-home'
# Define el arbol global de skills de Codex del runner efimero.
$CodexSkillsRoot = Join-Path $HOME '.agents\skills'
# Define el arbol global oficial de Antigravity del runner efimero.
$AntigravitySkillsRoot = Join-Path $HOME '.gemini\config\skills'
# Define la ruta del desinstalador real que se quiere probar.
$Uninstaller = Join-Path $BundleRoot 'scripts\Uninstall-SabasSecureDev.ps1'
# Conserva CODEX_HOME para restaurarlo al finalizar.
$PreviousCodexHome = $env:CODEX_HOME
# Conserva HERMES_HOME para restaurarlo al finalizar.
$PreviousHermesHome = $env:HERMES_HOME

# Falla antes de tocar nada si el runner ya contiene una instalacion Sabas inesperada.
foreach ($Root in @($CodexSkillsRoot, $AntigravitySkillsRoot)) {
    # Recorre cada skill propia.
    foreach ($SkillName in $SkillNames) {
        # Construye la ruta potencialmente preexistente.
        $ExistingSkill = Join-Path $Root $SkillName
        # Evita borrar por accidente una instalacion que no pertenece al fixture.
        if (Test-Path $ExistingSkill) { throw "Smoke test requires a clean runner; found: $ExistingSkill" }
    }
}
# Evita interactuar con una CLI Hermes real que pudiera existir en una imagen futura del runner.
if (Get-Command hermes -ErrorAction SilentlyContinue) { throw 'Smoke test requires a runner without a real Hermes CLI.' }

# Garantiza restauracion y limpieza aunque la prueba falle.
try {
    # Aisla el home de Codex.
    $env:CODEX_HOME = $FakeCodexHome
    # Aisla el home de Hermes.
    $env:HERMES_HOME = $FakeHermesHome
    # Crea las carpetas base del fixture.
    New-Item -ItemType Directory -Force -Path $FakeCodexHome, $FakeHermesHome, $CodexSkillsRoot, $AntigravitySkillsRoot | Out-Null
    # Crea las cuatro skills Sabas en Codex y Antigravity.
    foreach ($Root in @($CodexSkillsRoot, $AntigravitySkillsRoot)) {
        # Recorre las skills propias.
        foreach ($SkillName in $SkillNames) {
            # Define el directorio instalado simulado.
            $SkillPath = Join-Path $Root $SkillName
            # Crea la carpeta de la skill.
            New-Item -ItemType Directory -Force -Path $SkillPath | Out-Null
            # Crea un SKILL.md minimo para representar una instalacion activa.
            '# smoke fixture' | Set-Content -Path (Join-Path $SkillPath 'SKILL.md') -Encoding ascii
        }
    }
    # Crea tambien las cuatro skills en el HERMES_HOME aislado.
    foreach ($SkillName in $SkillNames) {
        # Define el destino Hermes simulado.
        $HermesSkillPath = Join-Path $FakeHermesHome ('skills\' + $SkillName)
        # Crea la carpeta de la skill.
        New-Item -ItemType Directory -Force -Path $HermesSkillPath | Out-Null
        # Crea un SKILL.md minimo.
        '# smoke fixture' | Set-Content -Path (Join-Path $HermesSkillPath 'SKILL.md') -Encoding ascii
    }
    # Crea el plugin Hermes administrado para comprobar que All lo retira del home aislado.
    $HermesPlugin = Join-Path $FakeHermesHome 'plugins\sabas-secure-development'
    # Crea la carpeta del plugin.
    New-Item -ItemType Directory -Force -Path $HermesPlugin | Out-Null
    # Crea el marcador de propiedad del bundle.
    '{"managed":true}' | Set-Content -Path (Join-Path $HermesPlugin '.sabas-managed-plugin.json') -Encoding ascii

    # Crea el directorio de hooks de Codex.
    $HooksDirectory = Join-Path $FakeCodexHome 'hooks'
    # Materializa la carpeta.
    New-Item -ItemType Directory -Force -Path $HooksDirectory | Out-Null
    # Define el script Sabas que debe desaparecer.
    $SabasHookScript = Join-Path $HooksDirectory 'sabas_secure_stop.py'
    # Crea el script simulado.
    '# smoke hook' | Set-Content -Path $SabasHookScript -Encoding ascii
    # Define hooks.json temporal.
    $HooksFile = Join-Path $FakeCodexHome 'hooks.json'
    # Construye texto Unicode sin depender de la codificacion fuente de PowerShell 5.1.
    $ForeignStatus = 'Revision ' + [char]0x00F1 + ' / caf' + [char]0x00E9 + ' / ' + [char]0x20AC
    # Define un hook ajeno que debe sobrevivir exactamente.
    $ForeignHook = [ordered]@{
        # Define el tipo de hook.
        type = 'command'
        # Define un comando no Sabas.
        command = 'python foreign_hook.py'
        # Conserva una cadena Unicode que detectaria mojibake.
        statusMessage = $ForeignStatus
    }
    # Define una entrada Sabas que el desinstalador debe filtrar.
    $SabasHook = [ordered]@{
        # Define el tipo de hook.
        type = 'command'
        # Incluye el nombre estable usado por el filtro del desinstalador.
        commandWindows = 'py -3 "C:\temp\sabas_secure_stop.py"'
        # Define el timeout del fixture.
        timeout = 25
        # Define un mensaje simple.
        statusMessage = 'Sabas smoke hook'
    }
    # Construye una configuracion compartida con una entrada Sabas y otra ajena.
    $HooksConfig = [ordered]@{
        # Define una descripcion de fixture.
        description = 'Smoke hooks'
        # Define el mapa de eventos.
        hooks = [ordered]@{
            # Define las dos entradas Stop independientes.
            Stop = @(
                # Envuelve el hook Sabas con la estructura real de Codex.
                [ordered]@{ hooks = @($SabasHook) },
                # Envuelve el hook ajeno con la misma estructura.
                [ordered]@{ hooks = @($ForeignHook) }
            )
        }
    }
    # Serializa el fixture con profundidad suficiente.
    $HooksJson = $HooksConfig | ConvertTo-Json -Depth 20
    # Crea un codificador UTF-8 sin BOM.
    $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    # Escribe hooks.json exactamente como UTF-8 sin BOM, reproduciendo el caso reportado por Codex.
    [System.IO.File]::WriteAllText($HooksFile, $HooksJson, $Utf8NoBom)

    # Ejecuta la retirada conjunta real contra los homes aislados del fixture.
    & $Uninstaller -Target All -RemoveCompletionHook

    # Verifica que las cuatro skills propias desaparecieron de Codex y Antigravity.
    foreach ($Root in @($CodexSkillsRoot, $AntigravitySkillsRoot)) {
        # Recorre cada skill esperada.
        foreach ($SkillName in $SkillNames) {
            # Falla si el desinstalador dejo una skill activa.
            if (Test-Path (Join-Path $Root $SkillName)) { throw "Smoke test: skill was not removed: $Root / $SkillName" }
        }
    }
    # Verifica que las cuatro skills propias desaparecieron tambien de Hermes.
    foreach ($SkillName in $SkillNames) {
        # Falla si queda una skill en el home Hermes aislado.
        if (Test-Path (Join-Path $FakeHermesHome ('skills\' + $SkillName))) { throw "Smoke test: Hermes skill was not removed: $SkillName" }
    }
    # Verifica que el plugin Hermes administrado fue retirado.
    if (Test-Path $HermesPlugin) { throw 'Smoke test: Hermes plugin was not removed.' }
    # Verifica que el script runtime del Stop Hook fue retirado.
    if (Test-Path $SabasHookScript) { throw 'Smoke test: Codex hook script was not removed.' }

    # Lee los bytes finales de hooks.json.
    $ResultBytes = [System.IO.File]::ReadAllBytes($HooksFile)
    # Comprueba que la desinstalacion no reintrodujo BOM.
    $HasBom = ($ResultBytes.Length -ge 3) -and ($ResultBytes[0] -eq 0xEF) -and ($ResultBytes[1] -eq 0xBB) -and ($ResultBytes[2] -eq 0xBF)
    # Falla si Codex volveria a rechazar el archivo.
    if ($HasBom) { throw 'Smoke test: hooks.json contains a UTF-8 BOM after uninstall.' }
    # Crea un decodificador UTF-8 estricto para validar los bytes resultantes.
    $Utf8Strict = New-Object System.Text.UTF8Encoding($false, $true)
    # Decodifica el JSON final.
    $ResultText = $Utf8Strict.GetString($ResultBytes)
    # Verifica que el texto Unicode del hook ajeno sobrevivio exactamente.
    if (-not $ResultText.Contains($ForeignStatus)) { throw 'Smoke test: non-ASCII foreign hook text was corrupted.' }
    # Verifica que la referencia Sabas fue retirada del JSON.
    if ($ResultText -match 'sabas_secure_stop\.py') { throw 'Smoke test: Sabas hook entry remained in hooks.json.' }
    # Parsea de nuevo el JSON para asegurar validez estructural.
    $ResultJson = $ResultText | ConvertFrom-Json
    # Serializa la configuracion restante para validar el comando ajeno.
    $RemainingJson = $ResultJson | ConvertTo-Json -Depth 20
    # Exige que el hook ajeno siga presente.
    if ($RemainingJson -notmatch 'foreign_hook\.py') { throw 'Smoke test: foreign hook was removed unexpectedly.' }

    # Emite un marcador inequívoco de exito para CI.
    Write-Host 'UNINSTALLER_SMOKE: PASS'
}
finally {
    # Restaura CODEX_HOME exactamente.
    if ($null -eq $PreviousCodexHome) { Remove-Item Env:CODEX_HOME -ErrorAction SilentlyContinue } else { $env:CODEX_HOME = $PreviousCodexHome }
    # Restaura HERMES_HOME exactamente.
    if ($null -eq $PreviousHermesHome) { Remove-Item Env:HERMES_HOME -ErrorAction SilentlyContinue } else { $env:HERMES_HOME = $PreviousHermesHome }
    # Elimina cualquier skill de fixture que pudiera quedar tras un fallo.
    foreach ($Root in @($CodexSkillsRoot, $AntigravitySkillsRoot)) {
        # Recorre las skills conocidas.
        foreach ($SkillName in $SkillNames) {
            # Elimina solo los directorios creados por este fixture.
            $SkillPath = Join-Path $Root $SkillName
            # Retira el residuo cuando exista.
            if (Test-Path $SkillPath) { Remove-Item -Recurse -Force -Path $SkillPath }
        }
    }
    # Elimina todos los homes temporales y hooks del fixture.
    if (Test-Path $TempRoot) { Remove-Item -Recurse -Force -Path $TempRoot }
}
