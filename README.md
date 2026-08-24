# Skill-desarrollo-seguro

**Skill de desarrollo seguro V0.5.4** es un sistema de desarrollo seguro para **OpenAI Codex** y **Hermes Agent**. Convierte la seguridad en una condición de finalización del cambio, no en una auditoría opcional al final.

La V0.5.4 comparte el mismo núcleo de seguridad entre ambos agentes y añade una integración nativa específica para cada uno.

## Qué incluye

- `sabas-secure-qa`: orquestador principal. Clasifica el cambio R0-R4, selecciona FAST/STANDARD/DEEP/RELEASE, coordina pruebas y emite el veredicto final.
- `sabas-threat-model`: crea y mantiene `SECURITY-THREAT-MODEL.md` con activos, actores, límites de confianza, permisos y casos de abuso.
- `sabas-security-bootstrap`: prepara un proyecto para trabajar con seguridad desde el principio.
- `usuario-torpe-qa`: prueba la aplicación como un usuario sin conocimientos, impaciente o propenso a errores. Su auditoría se mantiene separada de la fase de corrección.
- 20 skills defensivas externas opcionales fijadas a un commit concreto y limitadas por allowlist.
- `security_context.py`: clasificador determinista y generador del fingerprint SHA-256 del estado revisado.
- pruebas internas para evitar regresiones del propio sistema.

## Codex

En Codex se instala:

```text
~/.agents/skills/
├── sabas-secure-qa
├── sabas-threat-model
├── sabas-security-bootstrap
└── usuario-torpe-qa

~/.codex/
├── AGENTS.md                  # opcional, bloque administrado
└── hooks/
    └── sabas_secure_stop.py   # opcional
```

El Stop Hook impide cerrar cambios R2+ si la respuesta final no contiene un veredicto Sabas válido ligado al fingerprint actual del repositorio.

## Hermes

En Hermes se instala:

```text
<HERMES_HOME efectivo>/
├── skills/
│   ├── sabas-secure-qa
│   ├── sabas-threat-model
│   ├── sabas-security-bootstrap
│   └── usuario-torpe-qa
└── plugins/
    └── sabas-secure-development/
        ├── plugin.yaml
        └── __init__.py
```

El plugin nativo de Hermes registra dos controles:

- `pre_tool_call`: usa `block` como mínimo común compatible. Bloquea operaciones catastróficas, comandos destructivos sensibles y acceso automatizado a rutas como `.env`, claves privadas o la propia configuración de los guardrails. Si una operación sensible es legítima, se revisa y ejecuta manualmente.
- `pre_verify`: cuando la versión de Hermes lo soporta, para cambios R2/R3/R4 exige el mismo `SABAS_SECURITY_VERDICT` + `SABAS_SECURITY_FINGERPRINT` que Codex.

El instalador resuelve el home/perfil real combinando `hermes config path`, `HERMES_HOME` y el discovery real de `HERMES_PLUGINS_DEBUG`. Para decidir si el plugin Sabas está activo usa primero `hermes plugins list --plain --no-bundled`, evitando falsos `DEGRADED` cuando la tabla Rich acorta nombres largos con `…`; mantiene la tabla debug solo como evidencia secundaria. En Windows PowerShell 5.1, las salidas informativas de Hermes por `stderr` se capturan mediante un wrapper que conserva el código de salida real y evita falsos `NativeCommandError`. Antes de modificar ningún agente, Windows ejecuta además un `Native stderr compatibility probe` (`stderr + exit 0`) para comprobar esta compatibilidad en la máquina real. En Windows conoce tanto `%LOCALAPPDATA%\hermes` como el layout heredado `~\.hermes` y puede autocorregir el destino si la CLI demuestra que escanea el otro. Cuando confirma el home activo, puede retirar una copia antigua del plugin Sabas en un home alternativo solo si demuestra su propiedad y siempre guardando backup. También intenta activar `agent.verify_on_stop=auto`. Si una versión de Hermes no puede cargar el plugin, la instalación ya no se interrumpe: termina las skills y queda marcada como `DEGRADED`, con un diagnóstico en la carpeta de backup.

## Flujo

```text
Cambio de código
      │
      ▼
security_context.py
      │
      ├─ R0/R1 → FAST
      ├─ R2    → STANDARD
      ├─ R3    → DEEP
      └─ R4    → RELEASE/DEEP
      │
      ▼
Threat model cuando corresponde
      │
      ▼
Tests + secretos + SAST + SCA + revisión manual
      │
      ▼
Pruebas negativas / API / navegador cuando corresponda
      │
      ▼
usuario-torpe-qa en local/sandbox/staging autorizado
      │
      ▼
Corrección + regresiones + retest
      │
      ▼
security_context.py otra vez
      │
      ▼
SABAS_SECURITY_VERDICT: PASS | PASS WITH WARNINGS | BLOCKED
SABAS_SECURITY_FINGERPRINT: <sha256 actual>
```

Si cambia una sola línea después de la revisión, la huella cambia y el recibo anterior deja de ser válido.

## Instalación rápida en Windows

Descomprime el ZIP, abre PowerShell en `scripts` y desbloquea los archivos descargados:

```powershell
Get-ChildItem -Path ".." -Recurse -File | Unblock-File
```

Ejecuta el instalador sin `-Target` para que aparezca un menú:

```powershell
.\Install-SabasSecureDev.ps1 -InstallExternalSkills -ExternalProfile all -UpdateGlobalAgents -InstallCompletionHook
```

Verás:

```text
1) Codex
2) Hermes
3) Codex + Hermes
```

También puedes evitar el menú:

```powershell
# Solo Codex
.\Install-SabasSecureDev.ps1 -Target Codex -InstallExternalSkills -ExternalProfile all -UpdateGlobalAgents -InstallCompletionHook

# Solo Hermes
.\Install-SabasSecureDev.ps1 -Target Hermes -InstallExternalSkills -ExternalProfile all

# Ambos
.\Install-SabasSecureDev.ps1 -Target Both -InstallExternalSkills -ExternalProfile all -UpdateGlobalAgents -InstallCompletionHook
```

Consulta [INSTALL.md](INSTALL.md) para los detalles.

## Comprobar el propio sistema

```powershell
.\Test-SabasSecureDev.ps1
```

Comprueba, entre otras cosas:

- integridad del bundle;
- sintaxis Python;
- comportamiento básico del Tool Guard de Hermes;
- validación del recibo Codex/Hermes;
- invalidación del fingerprint cuando cambia el repositorio;
- en CI Windows, una instalación Hermes completa contra una CLI simulada (`Invoke-HermesInstallerSmoke.ps1`), además del parseo nativo de todos los `.ps1`.

## Publicarlo en tu GitHub

El repositorio está preparado para contener en el mismo sitio las skills Sabas y `usuario-torpe-qa`.

Con GitHub CLI autenticado (`gh auth login`), desde `scripts`:

```powershell
.\Publish-To-GitHub.ps1
```

Por seguridad crea `sabas-secure-development` como **privado** por defecto. Para hacerlo público:

```powershell
.\Publish-To-GitHub.ps1 -Visibility public
```

## CI del repositorio

El bundle incluye `.github/workflows/validate.yml`. En cada `push` y `pull_request` valida los `.ps1` con el parser real de PowerShell y ejecuta las autopruebas en Windows y Linux. Las Actions usadas por el workflow están fijadas a SHA completos para reducir riesgo de supply chain.

## Seguridad y límites

Este proyecto aplica defensa en profundidad, pero no puede prometer seguridad absoluta. Un `PASS` significa que las comprobaciones aplicables se ejecutaron correctamente para el estado identificado por el fingerprint; no significa que sea imposible que exista una vulnerabilidad desconocida.

Los hooks de Codex y Hermes son guardrails dentro de sus respectivos agentes, no un sandbox del sistema operativo. En Hermes, `pre_verify` está sujeto al límite nativo de nudges de la plataforma; el Tool Guard `pre_tool_call` añade una barrera separada y deliberadamente conservadora para operaciones peligrosas. Los hooks son defensa en profundidad, no sustituyen permisos del sistema operativo ni un sandbox.

Las pruebas dinámicas de `usuario-torpe-qa` y cualquier DAST destructivo solo deben ejecutarse tras confirmar que el destino es local, sandbox o staging autorizado y que no contiene datos reales que puedan verse afectados.

## Diagnóstico de Hermes

Si una versión concreta de Hermes cambia su sistema de plugins, ejecuta:

```powershell
.\scripts\Diagnose-Hermes.ps1
```

El diagnóstico muestra versión, `config path`, perfil y discovery con `HERMES_PLUGINS_DEBUG=1`, sin leer el contenido de `config.yaml`, `.env` ni credenciales.
