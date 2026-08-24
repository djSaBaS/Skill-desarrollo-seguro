# Instalación — Sabas Secure Development V0.5.4

## Requisitos

- Windows PowerShell 5.1 o PowerShell 7+ para los instaladores incluidos.
- Python 3.
- Git si vas a instalar las skills externas.
- Codex instalado si eliges Codex.
- Hermes Agent instalado si eliges Hermes. Si la CLI `hermes` está en `PATH`, el instalador valida y activa automáticamente el plugin.

## 1. Desbloquear el ZIP descargado

Desde la carpeta `scripts`:

```powershell
Get-ChildItem -Path ".." -Recurse -File | Unblock-File
```

Esto evita modificar permanentemente la política global de ejecución de PowerShell.

## 2. Elegir destino mediante menú

Ejecuta:

```powershell
.\Install-SabasSecureDev.ps1 -InstallExternalSkills -ExternalProfile all -UpdateGlobalAgents -InstallCompletionHook
```

El instalador preguntará:

```text
Selecciona dónde instalar Sabas Secure Development V0.5.4:
  1) Codex
  2) Hermes
  3) Codex + Hermes
```

Los parámetros específicos de Codex (`-UpdateGlobalAgents` y `-InstallCompletionHook`) se ignoran de forma natural si eliges únicamente Hermes.

## 3. Instalación no interactiva

### Codex

```powershell
.\Install-SabasSecureDev.ps1 `
    -Target Codex `
    -InstallExternalSkills `
    -ExternalProfile all `
    -UpdateGlobalAgents `
    -InstallCompletionHook
```

### Hermes

```powershell
.\Install-SabasSecureDev.ps1 `
    -Target Hermes `
    -InstallExternalSkills `
    -ExternalProfile all
```

### Codex + Hermes

```powershell
.\Install-SabasSecureDev.ps1 `
    -Target Both `
    -InstallExternalSkills `
    -ExternalProfile all `
    -UpdateGlobalAgents `
    -InstallCompletionHook
```

## Qué hace antes de modificar nada

1. Hace que el parser nativo de PowerShell analice todos los `.ps1` auxiliares.
2. Ejecuta `validate_bundle.py`.
3. Verifica `MANIFEST.sha256`.
4. Comprueba estructura de las skills, JSON y sintaxis Python.

Si cualquiera de esas comprobaciones falla, la instalación se detiene.

## Instalación Codex

Las skills se copian en:

```text
$HOME\.agents\skills
```

El instalador conserva versiones previas en:

```text
$HOME\.sabas-secure-development\backups\<fecha>
```

Con `-UpdateGlobalAgents`, añade un bloque delimitado y actualizable dentro de:

```text
$CODEX_HOME\AGENTS.md
```

Si existe un `AGENTS.override.md` no vacío, también garantiza el bloque allí para que la configuración efectiva no deje el gate fuera.

Con `-InstallCompletionHook`, instala:

```text
$CODEX_HOME\hooks\sabas_secure_stop.py
```

y fusiona su entrada con `hooks.json` preservando otros hooks.

Después abre `/hooks` en Codex, revisa el hook Sabas y confíalo únicamente si la definición apunta al script instalado.

## Instalación Hermes

Las skills se copian en:

```text
$HERMES_HOME\skills
```

El plugin se copia en:

```text
$HERMES_HOME\plugins\sabas-secure-development
```

Cuando `hermes` está disponible en `PATH`, el instalador combina `hermes config path`, `HERMES_HOME` y `HERMES_PLUGINS_DEBUG=1 hermes plugins list`. La comprobación primaria de estado usa `hermes plugins list --plain --no-bundled`, porque la tabla visual puede truncar `sabas-secure-development` según el ancho de consola. En Windows compara además `%LOCALAPPDATA%\hermes` con el layout heredado `~\.hermes`. Si el primer destino no funciona, prueba de forma controlada los candidatos seguros y conserva el que Hermes realmente descubre. Una copia Sabas antigua en un home alternativo solo se retira si el instalador puede demostrar que es una copia gestionada por este proyecto y siempre se guarda antes en el backup de la ejecución.

Después valida el Python del plugin, consulta `hermes plugins -h` para adaptar el flujo a los subcomandos realmente disponibles y prueba discovery/enable sin asumir una versión concreta:

```text
hermes plugins enable sabas-secure-development
HERMES_PLUGINS_DEBUG=1 hermes plugins list
hermes config set agent.verify_on_stop auto
hermes config set agent.coding_instructions <reglas-Sabas>
```

Se intenta `enable` antes de exigir que aparezca en `plugins list` porque algunas versiones antiguas no enumeran de la misma forma plugins todavía no activados. Si `enable` falla pero discovery ya ve el plugin, se reintenta una vez. Si un candidato de ruta falla y no existía previamente, la copia temporal se retira para no dejar plugins huérfanos.

Si la versión instalada no descubre o no puede cargar el plugin, V0.5.4 **no aborta a mitad**: conserva las skills principales, intenta completar las skills externas solicitadas y marca la integración Hermes como `DEGRADED`. Los fallos externos de red/upstream también se aíslan y se muestran como `External defensive skills: FAILED` en vez de ocultarse. El instalador guarda `hermes-plugin-diagnostic.txt` dentro de su carpeta de backup con versión, capacidades CLI, rutas probadas y salida de discovery, sin leer `.env`, claves ni contenido de `config.yaml`.

Si el comando `hermes` no está en `PATH`, los archivos se copian pero aparecerá una advertencia. Cuando Hermes esté disponible, ejecuta:

```text
hermes plugins enable sabas-secure-development
hermes config set agent.verify_on_stop auto
```

## usuario-torpe-qa

Se gestiona por separado en cada agente seleccionado.

- Si ya existe `usuario-torpe-qa/SKILL.md`, se preserva íntegro.
- Solo se completan referencias/plantillas que falten.
- Si no existe, se instala la copia completa incluida en el repositorio.
- Su confirmación de seguridad original sigue siendo obligatoria antes de pruebas destructivas.

## Skills externas

`-InstallExternalSkills` descarga únicamente un allowlist fijado en `EXTERNAL-SKILLS.lock.json`.

Fuente fijada:

```text
https://github.com/mukul975/Anthropic-Cybersecurity-Skills.git
```

Commit fijado:

```text
f76261573a539ec40c3d434ecbb9e657d26aa921
```

Perfiles:

- `web`: 10 skills.
- `api`: web + 5 API.
- `devsecops`: web + 5 DevSecOps.
- `all`: 20 skills defensivas.

Cuando usas `-Target Both`, el repositorio externo se clona una sola vez y las skills validadas se copian a ambos árboles.

No se instalan automáticamente skills de explotación, evasión, post-explotación, C2, cracking o bypass ofensivo.

## Pruebas del paquete

Ejecuta:

```powershell
.\Test-SabasSecureDev.ps1
```

El instalador también ejecuta esta batería ligera al final. El workflow de GitHub añade en `windows-latest` una prueba de instalación Hermes aislada con CLI simulada, para detectar regresiones de PowerShell, discovery y enable antes de publicar cambios.

## Verificar Codex

Recarga VS Code/Codex y revisa:

```text
/skills
/hooks
```

Debes encontrar al menos:

```text
sabas-secure-qa
sabas-threat-model
sabas-security-bootstrap
usuario-torpe-qa
```

## Verificar Hermes

Reinicia Hermes y ejecuta:

```powershell
hermes plugins list --plain --no-bundled
```

Debe aparecer `sabas-secure-development` con estado `enabled`. Esta vista compacta es la comprobación recomendada por V0.5.4 porque no depende del ancho de la tabla gráfica. Después puedes ejecutar también:

```text
hermes plugins list
hermes config get agent.verify_on_stop
```

El plugin `sabas-secure-development` debe estar habilitado y `verify_on_stop` debe resolver a `auto`.

## Publicar el repositorio

Si tienes GitHub CLI autenticado:

```powershell
.\Publish-To-GitHub.ps1
```

El script crea por defecto:

```text
<tu-usuario>/sabas-secure-development
```

como repositorio privado y publica el contenido controlado del bundle. No utiliza ni imprime tu token.

### Actualización desde V0.5/V0.5.1 con instalación Hermes parcial

No hace falta desinstalar. V0.5/V0.5.1 ya pueden haber copiado skills y plugin antes de detenerse. Ejecuta V0.5.4 sobre la misma instalación: hará backup, detectará el home/perfil mediante config + discovery, probará ambos layouts Windows conocidos si hace falta, volverá a copiar los componentes en el destino confirmado y continuará aunque una capa opcional quede degradada.

Para diagnóstico manual:

```powershell
.\Diagnose-Hermes.ps1
```
