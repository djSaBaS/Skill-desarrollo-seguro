# Instalación y actualización — Sabas Secure Development

Este bundle combina **Sabas Secure Development V0.5.4** con **Sabas Efficient Development V0.2.0** y soporta:

- OpenAI Codex CLI/IDE;
- Hermes Agent;
- Google Antigravity IDE.

La forma recomendada de trabajar es mediante `Setup-SabasSecureDev.ps1`. El instalador V0.5.4 original se conserva como motor interno probado para Codex/Hermes.

## Requisitos

- Windows PowerShell 5.1 o PowerShell 7+ para los scripts incluidos.
- Python 3.
- Git si vas a instalar skills defensivas externas.
- Codex si eliges Codex.
- Hermes Agent si eliges Hermes.
- Google Antigravity IDE si eliges Antigravity.

## 1. Desbloquear un ZIP descargado

Desde `scripts`:

```powershell
Get-ChildItem -Path ".." -Recurse -File | Unblock-File
```

No es necesario cambiar permanentemente la Execution Policy.

## 2. Instalación recomendada

Desde `scripts`:

```powershell
.\Setup-SabasSecureDev.ps1
```

El selector muestra:

```text
1) Codex
2) Hermes Agent
3) Google Antigravity IDE
4) Todos
```

### Codex

```powershell
.\Setup-SabasSecureDev.ps1 `
    -Target Codex `
    -UpdateGlobalAgents `
    -InstallCompletionHook
```

Con las skills defensivas externas opcionales:

```powershell
.\Setup-SabasSecureDev.ps1 `
    -Target Codex `
    -InstallExternalSkills `
    -ExternalProfile all `
    -UpdateGlobalAgents `
    -InstallCompletionHook
```

### Hermes

```powershell
.\Setup-SabasSecureDev.ps1 -Target Hermes
```

Con skills externas:

```powershell
.\Setup-SabasSecureDev.ps1 `
    -Target Hermes `
    -InstallExternalSkills `
    -ExternalProfile all
```

### Google Antigravity IDE

```powershell
.\Setup-SabasSecureDev.ps1 -Target Antigravity
```

### Todos

```powershell
.\Setup-SabasSecureDev.ps1 `
    -Target All `
    -UpdateGlobalAgents `
    -InstallCompletionHook
```

`All` instala las skills propias en los tres agentes. Las skills externas opcionales siguen instalándose únicamente en Codex/Hermes porque su integración y allowlist fueron validadas originalmente para esos agentes.

## 3. Qué hace el setup portable

Para Codex/Hermes:

1. delega en `Install-SabasSecureDev.ps1`, que conserva las validaciones y discovery V0.5.4;
2. instala/actualiza también `sabas-efficient-development`;
3. conserva backups antes de reemplazar la copia anterior;
4. en Codex, normaliza `hooks.json` a UTF-8 sin BOM;
5. en Codex, compara por SHA-256 `sabas_secure_stop.py` instalado contra la copia auditada del bundle.

Para Antigravity:

1. ejecuta `Test-SabasSecureDev.ps1` antes de copiar;
2. instala las Agent Skills propias en la ruta global oficial;
3. preserva una copia existente de `usuario-torpe-qa`;
4. no instala hooks ni plugins fuera del mecanismo de Agent Skills.

## 4. Actualización desde GitHub

Puedes actualizar sin descargar manualmente otro ZIP:

```powershell
.\Update-SabasSecureDev.ps1 -Target Codex -UpdateGlobalAgents -InstallCompletionHook
```

```powershell
.\Update-SabasSecureDev.ps1 -Target Hermes
```

```powershell
.\Update-SabasSecureDev.ps1 -Target Antigravity
```

```powershell
.\Update-SabasSecureDev.ps1 -Target All -UpdateGlobalAgents -InstallCompletionHook
```

El actualizador:

1. descarga el repositorio oficial `djSaBaS/Skill-desarrollo-seguro`;
2. usa `main` por defecto;
3. expande el bundle en una carpeta temporal;
4. localiza exactamente un `Setup-SabasSecureDev.ps1`;
5. ejecuta el setup con `-Action Update`;
6. elimina siempre la carpeta temporal.

La actualización sigue pasando por las validaciones del bundle. No se hace un `curl | powershell` ni se ejecuta una respuesta de red directamente.

Puedes indicar otra referencia pública:

```powershell
.\Update-SabasSecureDev.ps1 -Target Codex -Ref main
```

## 5. Codex

### Skills

Ruta global:

```text
~/.agents/skills/
├── sabas-efficient-development/
├── sabas-secure-qa/
├── sabas-threat-model/
├── sabas-security-bootstrap/
└── usuario-torpe-qa/
```

### Instrucciones globales

Con `-UpdateGlobalAgents` se actualiza el bloque administrado dentro de:

```text
$CODEX_HOME/AGENTS.md
```

Cuando existe un `AGENTS.override.md` efectivo, el instalador V0.5.4 mantiene también allí el gate para que el override no lo desactive accidentalmente.

### Stop Hook

Con `-InstallCompletionHook`:

```text
$CODEX_HOME/hooks/sabas_secure_stop.py
$CODEX_HOME/hooks.json
```

Codex mostrará un aviso porque los hooks pueden ejecutarse fuera del sandbox. Eso es correcto: revisa siempre el comando antes de confiar.

El setup portable añade dos controles:

- `hooks.json` se reescribe como UTF-8 **sin BOM**, evitando el error `expected value at line 1 column 1` observado con un JSON creado por Windows PowerShell 5.1;
- el SHA-256 del hook instalado debe coincidir con `scripts/SabasSecureStopHook.py` del bundle.

Después de instalar:

```text
/skills
/hooks
```

Comprueba que el hook apunta a:

```text
$CODEX_HOME/hooks/sabas_secure_stop.py
```

## 6. Hermes Agent

El motor V0.5.4 mantiene su resolución adaptativa del home mediante:

- `hermes config path`;
- `HERMES_HOME`;
- discovery con `HERMES_PLUGINS_DEBUG`;
- `%LOCALAPPDATA%\hermes` en Windows;
- fallback histórico `~/.hermes`.

Instala:

```text
<HERMES_HOME efectivo>/
├── skills/
│   ├── sabas-efficient-development/
│   ├── sabas-secure-qa/
│   ├── sabas-threat-model/
│   ├── sabas-security-bootstrap/
│   └── usuario-torpe-qa/
└── plugins/
    └── sabas-secure-development/
```

Verifica:

```powershell
hermes plugins list --plain --no-bundled
```

y, cuando lo soporte tu versión:

```powershell
hermes config get agent.verify_on_stop
```

La integración puede quedar `DEGRADED` si una versión concreta de Hermes no carga el plugin; las skills siguen instalándose.

## 7. Google Antigravity IDE

La documentación oficial actual de Antigravity usa:

```text
~/.gemini/config/skills/<skill-folder>/SKILL.md
```

para skills globales y:

```text
<workspace>/.agents/skills/<skill-folder>/SKILL.md
```

para skills del proyecto.

El setup instala globalmente:

```text
~/.gemini/config/skills/
├── sabas-efficient-development/
├── sabas-secure-qa/
├── sabas-threat-model/
├── sabas-security-bootstrap/
└── usuario-torpe-qa/
```

Antigravity aplica divulgación progresiva: al iniciar una conversación conoce nombre/descripción de las skills y carga el contenido completo cuando una resulta relevante.

Esta integración no instala el Stop Hook de Codex ni el plugin de Hermes.

Consulta [ANTIGRAVITY.md](ANTIGRAVITY.md) para detalles y la diferencia con Antigravity CLI.

## 8. usuario-torpe-qa

La política es conservadora:

- si ya existe `usuario-torpe-qa/SKILL.md`, se preserva;
- el motor Codex/Hermes V0.5.4 puede completar referencias auxiliares faltantes;
- Antigravity no sobrescribe una copia existente de procedencia distinta;
- ninguna instalación autoriza por sí misma pruebas destructivas.

## 9. Skills defensivas externas

`-InstallExternalSkills` se mantiene para Codex/Hermes.

El origen y commit se encuentran fijados en `EXTERNAL-SKILLS.lock.json`. No se instala el catálogo ofensivo completo.

Perfiles:

- `web`;
- `api`;
- `devsecops`;
- `all`.

Para Antigravity el setup portable no copia automáticamente estas skills externas. Primero deben revisarse para ese runtime.

## 10. Autopruebas

Ejecuta:

```powershell
.\Test-SabasSecureDev.ps1
```

La batería valida tanto el núcleo existente como la capa portable:

- manifiesto e integridad;
- plugin Hermes;
- fingerprints;
- regresiones de discovery Windows;
- ruta oficial de Antigravity;
- setup/actualizador;
- presencia de la reparación UTF-8 sin BOM;
- documentación básica de la skill eficiente.

## 11. Backups

Las instalaciones existentes se conservan antes de reemplazarlas.

El motor V0.5.4 usa:

```text
~/.sabas-secure-development/backups/<fecha>/
```

El wrapper portable añade:

```text
~/.sabas-secure-development/backups/portable-<fecha>/
```

## 12. Instalador V0.5.4 directo

`scripts/Install-SabasSecureDev.ps1` sigue disponible para compatibilidad y para las pruebas existentes de Codex/Hermes.

Para nuevas instalaciones se recomienda **`Setup-SabasSecureDev.ps1`**, porque además:

- incluye `sabas-efficient-development`;
- soporta Antigravity IDE;
- repara el BOM de `hooks.json`;
- verifica el hash del hook.

## 13. Diagnóstico Hermes

```powershell
.\Diagnose-Hermes.ps1
```

Muestra versión, perfil, ruta efectiva y discovery sin leer `.env`, claves o contenido de configuración sensible.
