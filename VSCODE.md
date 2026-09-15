# Uso con Codex en VS Code

Sabas Secure Development se instala en Codex IDE/VS Code mediante Agent Skills globales y, opcionalmente, un bloque administrado de instrucciones y un Stop Hook de finalización.

La vía recomendada desde esta actualización es `Setup-SabasSecureDev.ps1`; el instalador V0.5.4 original permanece como motor interno y compatibilidad heredada.

## Instalación recomendada

Desde `scripts`:

```powershell
.\Setup-SabasSecureDev.ps1 `
    -Target Codex `
    -UpdateGlobalAgents `
    -InstallCompletionHook
```

Para añadir las skills defensivas externas allowlisted:

```powershell
.\Setup-SabasSecureDev.ps1 `
    -Target Codex `
    -InstallExternalSkills `
    -ExternalProfile all `
    -UpdateGlobalAgents `
    -InstallCompletionHook
```

El setup instala también `sabas-efficient-development`, por lo que Codex puede acotar prompts amplios antes de explorar el repositorio.

## Actualización

Desde una copia ya instalada del repositorio:

```powershell
.\Update-SabasSecureDev.ps1 `
    -Target Codex `
    -UpdateGlobalAgents `
    -InstallCompletionHook
```

El actualizador descarga `main` del repositorio oficial por defecto, ejecuta el setup en modo `Update` y conserva backups antes de sustituir componentes.

## Desinstalación

Para retirar las cuatro skills propias de Sabas y, de forma explícita, el bloque global y el Stop Hook:

```powershell
.\Uninstall-SabasSecureDev.ps1 `
    -Target Codex `
    -RemoveGlobalAgentsBlock `
    -RemoveCompletionHook
```

La retirada del Stop Hook no reemplaza `hooks.json` a ciegas: elimina únicamente la entrada que referencia `sabas_secure_stop.py`, preserva las demás entradas, decodifica el archivo como UTF-8 estricto y lo escribe sin BOM. Esto evita que Windows PowerShell 5.1 corrompa texto no ASCII perteneciente a otros hooks.

`usuario-torpe-qa` solo se retira si además indicas `-RemoveBundledUsuarioTorpe` y la copia instalada conserva el marcador de propiedad del bundle. Las skills externas se dejan intactas.

## Árbol esperado

```text
~/.agents/skills/
├── sabas-efficient-development/
├── sabas-secure-qa/
├── sabas-threat-model/
├── sabas-security-bootstrap/
└── usuario-torpe-qa/

$CODEX_HOME/
├── AGENTS.md                     # opcional
├── AGENTS.override.md            # solo si ya existe y resulta aplicable
├── hooks.json                    # cuando se instala el Stop Hook
└── hooks/
    └── sabas_secure_stop.py
```

## Scope Compiler y consumo

`sabas-efficient-development` evita interpretar una orden genérica como permiso para hacer trabajo ilimitado. Por ejemplo, `corrige los errores de Sonar` debe reutilizar los hallazgos existentes y trabajar por un lote pequeño y verificable antes de continuar.

Por defecto evita `deep scan` completo, scans duplicados, subagentes paralelos, procesos largos en segundo plano y suites globales prematuras. Si el problema exige ampliar el alcance, el agente debe justificarlo.

La capa de eficiencia no puede omitir tests, migraciones o gates de seguridad que sean realmente obligatorios.

## Stop Hook de Codex

Con `-InstallCompletionHook`, Codex registra un hook `Stop` que ejecuta:

```text
$CODEX_HOME/hooks/sabas_secure_stop.py
```

Codex muestra un aviso de confianza porque un hook puede ejecutarse fuera del sandbox. Ese aviso es correcto y debe respetarse: revisa el comando antes de confiarlo.

El hook Sabas incluido en este repositorio:

- recibe el evento de Codex por `stdin`;
- ejecuta únicamente el clasificador local `security_context.py` del bundle;
- no usa `shell=True`;
- no descarga contenido de Internet;
- no modifica el proyecto;
- aplica timeout;
- evita ciclos mediante el estado del hook;
- puede pedir una continuación cuando falta un recibo de seguridad válido para el cambio actual.

El setup portable compara por SHA-256 el hook instalado con la copia auditada del bundle. Si no coinciden, la instalación falla antes de considerarlo válido.

## `hooks.json` y Windows PowerShell 5.1

Se detectó una incompatibilidad real: `Set-Content -Encoding utf8` en Windows PowerShell 5.1 puede escribir BOM (`EF BB BF`), mientras que el parser actual de Codex espera que el JSON empiece directamente por `{`.

Después de ejecutar el instalador V0.5.4, el setup portable vuelve a validar `hooks.json` y lo reescribe en UTF-8 sin BOM mediante .NET. No cambia su estructura JSON ni elimina hooks ajenos.

El mismo criterio se aplica al desinstalar: `Uninstall-SabasSecureDev.ps1 -RemoveCompletionHook` lee bytes, usa un decodificador UTF-8 estricto, conserva hooks ajenos y escribe el JSON resultante sin BOM.

Si quieres comprobarlo manualmente:

```powershell
$HooksFile = Join-Path $HOME '.codex\hooks.json'
$Bytes = [System.IO.File]::ReadAllBytes($HooksFile)
($Bytes[0..7] | ForEach-Object { $_.ToString('X2') }) -join ' '
```

Debe empezar por `7B`, no por `EF BB BF`.

## Verificación en Codex

Después de instalar o actualizar, recarga VS Code/Codex y revisa:

```text
/skills
/hooks
```

En `/skills` deben aparecer las skills Sabas instaladas. En `/hooks`, revisa que el comando del Stop Hook apunte a `sabas_secure_stop.py` dentro de tu `$CODEX_HOME` antes de marcarlo como confiable.

## Flujo diario recomendado

1. Usa `sabas-efficient-development` para mantener el alcance pequeño y reutilizar evidencia ya disponible.
2. Deja que `sabas-secure-qa` clasifique el riesgo real del cambio.
3. Para cambios normales, prioriza revisión y pruebas enfocadas en el diff.
4. Reserva `DEEP`/`RELEASE` y scans amplios para riesgo alto real, release o petición explícita.
5. Ejecuta `usuario-torpe-qa` solo en local/sandbox/staging autorizado.

## Codex Security oficial

Cuando Codex exponga su capa oficial de seguridad, `sabas-secure-qa` puede usarla como evidencia adicional según riesgo. No debe repetir automáticamente un scan completo si ya existe evidencia suficiente para una remediación localizada.

La ausencia de una herramienta nunca equivale a un resultado limpio: cualquier verificación no ejecutada debe quedar como `NOT VERIFIED` cuando sea relevante.
