# Skill-desarrollo-seguro

**Sabas Secure Development V0.5.4** + **Sabas Efficient Development V0.2.0** forman un bundle portable para desarrollo seguro y eficiente con **OpenAI Codex**, **Hermes Agent** y **Google Antigravity IDE**.

La seguridad sigue siendo una condición de finalización del cambio. La capa de eficiencia añade un Scope Compiler que evita convertir peticiones amplias en scans, lecturas y agentes innecesarios.

## Qué incluye

- `sabas-efficient-development`: reduce consumo innecesario, acota prompts amplios y trabaja por lotes verificables.
- `sabas-secure-qa`: orquestador de seguridad R0-R4 con modos FAST/STANDARD/DEEP/RELEASE.
- `sabas-threat-model`: crea y mantiene `SECURITY-THREAT-MODEL.md`.
- `sabas-security-bootstrap`: prepara un proyecto para trabajar con seguridad desde el principio.
- `usuario-torpe-qa`: prueba flujos como un usuario propenso a errores, siempre en entorno autorizado.
- `security_context.py`: clasificador determinista y generador del fingerprint SHA-256.
- plugin nativo de Hermes para guardrails adicionales.
- Stop Hook opcional de Codex ligado al fingerprint del cambio.
- 20 skills defensivas externas opcionales, fijadas por allowlist/commit para Codex y Hermes.
- autopruebas y manifiesto SHA-256 del bundle.

## Nuevo entrypoint portable

La forma recomendada de instalar o refrescar el bundle es:

```powershell
cd scripts
.\Setup-SabasSecureDev.ps1
```

El selector ofrece:

```text
1) Codex
2) Hermes Agent
3) Google Antigravity IDE
4) Todos
```

Instalación directa:

```powershell
# Codex
.\Setup-SabasSecureDev.ps1 -Target Codex -UpdateGlobalAgents -InstallCompletionHook

# Hermes
.\Setup-SabasSecureDev.ps1 -Target Hermes

# Antigravity IDE
.\Setup-SabasSecureDev.ps1 -Target Antigravity

# Todos
.\Setup-SabasSecureDev.ps1 -Target All -UpdateGlobalAgents -InstallCompletionHook
```

El setup reutiliza el instalador V0.5.4 probado para Codex/Hermes y añade la capa portable necesaria para:

- instalar `sabas-efficient-development` también en Codex/Hermes;
- instalar todas las Agent Skills propias en Antigravity IDE;
- corregir/validar `hooks.json` de Codex como UTF-8 **sin BOM**;
- verificar por SHA-256 que el hook runtime de Codex coincide con la copia auditada del bundle;
- conservar backups antes de reemplazar una skill existente.

## Actualización desde GitHub

No hace falta descargar manualmente otro ZIP para actualizar:

```powershell
cd scripts

# Actualizar Codex
.\Update-SabasSecureDev.ps1 -Target Codex -UpdateGlobalAgents -InstallCompletionHook

# Actualizar Hermes
.\Update-SabasSecureDev.ps1 -Target Hermes

# Actualizar Antigravity IDE
.\Update-SabasSecureDev.ps1 -Target Antigravity

# Actualizar todos
.\Update-SabasSecureDev.ps1 -Target All -UpdateGlobalAgents -InstallCompletionHook
```

El actualizador descarga la referencia pública indicada (`main` por defecto), extrae el bundle en una carpeta temporal y ejecuta `Setup-SabasSecureDev.ps1 -Action Update`. El propio setup/instalador ejecuta la validación del bundle antes de copiar componentes.

Puedes fijar otra referencia pública:

```powershell
.\Update-SabasSecureDev.ps1 -Target Codex -Ref main
```

## Codex

Codex usa:

```text
~/.agents/skills/
├── sabas-efficient-development
├── sabas-secure-qa
├── sabas-threat-model
├── sabas-security-bootstrap
└── usuario-torpe-qa

$CODEX_HOME/
├── AGENTS.md                  # opcional
└── hooks/
    └── sabas_secure_stop.py   # opcional
```

El Stop Hook se ejecuta al intentar cerrar el turno y puede pedir una continuación de seguridad para cambios R2+. Codex avisa correctamente de que los hooks pueden ejecutarse fuera del sandbox: debes revisar/confiar este hook solo cuando apunte a la copia instalada por Sabas.

El setup portable comprueba que la huella SHA-256 del hook instalado coincide con la fuente auditada del bundle y normaliza `hooks.json` a UTF-8 sin BOM para evitar el error `expected value at line 1 column 1` observado en Windows PowerShell 5.1.

## Hermes

Hermes mantiene:

```text
<HERMES_HOME efectivo>/
├── skills/
│   ├── sabas-efficient-development
│   ├── sabas-secure-qa
│   ├── sabas-threat-model
│   ├── sabas-security-bootstrap
│   └── usuario-torpe-qa
└── plugins/
    └── sabas-secure-development/
        ├── plugin.yaml
        └── __init__.py
```

El instalador principal conserva su discovery adaptativo mediante `hermes config path`, `HERMES_HOME`, `HERMES_PLUGINS_DEBUG`, `%LOCALAPPDATA%\hermes` y `~/.hermes`. El setup portable localiza después ese árbol efectivo para añadir/actualizar `sabas-efficient-development`.

## Google Antigravity IDE

Antigravity utiliza el estándar Agent Skills y carga el cuerpo completo de una skill solo cuando la considera relevante.

Ruta global oficial:

```text
~/.gemini/config/skills/<skill-name>/SKILL.md
```

Ruta por workspace:

```text
<workspace>/.agents/skills/<skill-name>/SKILL.md
```

El setup instala globalmente las skills Sabas en `~/.gemini/config/skills/`.

En Antigravity **no** instala el Stop Hook de Codex ni el plugin de Hermes. La integración es deliberadamente declarativa mediante Agent Skills.

Antigravity CLI mantiene un árbol global distinto (`~/.gemini/antigravity-cli/skills/`); el setup de este repositorio está dirigido a **Antigravity IDE**. Consulta [ANTIGRAVITY.md](ANTIGRAVITY.md).

## Flujo de eficiencia

Una petición como:

```text
corrige los errores de Sonar
```

no implica automáticamente:

```text
auditoría completa -> deep scan -> subagentes -> suite global
```

`sabas-efficient-development` la acota, por defecto, a:

```text
evidencia ya disponible
      ↓
1 causa raíz o hasta 3 hallazgos relacionados
      ↓
working set pequeño (normalmente <= 5 archivos de producción)
      ↓
cambio mínimo
      ↓
pruebas dirigidas
      ↓
informe + STOP
```

Si resolver correctamente el problema exige ampliar el alcance, el agente debe justificarlo.

## Flujo de seguridad

```text
Cambio de código
      ↓
security_context.py
      ├─ R0/R1 → FAST
      ├─ R2    → STANDARD
      ├─ R3    → DEEP
      └─ R4    → RELEASE
      ↓
gates aplicables + pruebas dirigidas
      ↓
corrección + regresión + retest
      ↓
security_context.py
      ↓
SABAS_SECURITY_VERDICT
SABAS_SECURITY_FINGERPRINT
```

La capa de eficiencia no puede saltarse gates obligatorios; evita trabajo duplicado dentro de ellos.

## Autopruebas

Desde `scripts`:

```powershell
.\Test-SabasSecureDev.ps1
```

Comprueba el núcleo de seguridad y la integración portable:

- integridad de `MANIFEST.sha256`;
- sintaxis/estructura del bundle;
- guardrails Hermes;
- fingerprints Codex/Hermes;
- regresiones de discovery;
- rutas actuales de Antigravity;
- presencia del Scope Compiler;
- reparación UTF-8 sin BOM de hooks;
- estructura del actualizador portable.

## Documentación

- [INSTALL.md](INSTALL.md): instalación, actualización y verificación.
- [ANTIGRAVITY.md](ANTIGRAVITY.md): integración específica de Google Antigravity.
- [VSCODE.md](VSCODE.md): Codex en VS Code.
- [SECURITY.md](SECURITY.md): límites de confianza y política de seguridad.
- [EXTERNAL-SKILLS.md](EXTERNAL-SKILLS.md): skills defensivas externas.

## Seguridad y límites

Un `PASS` no garantiza ausencia absoluta de vulnerabilidades. Significa que los controles aplicables se ejecutaron para el estado identificado por el fingerprint.

Los hooks son código local con permisos del usuario. Revisa siempre cualquier hook nuevo/modificado antes de confiarlo. El hook Sabas incluido en este repositorio no sustituye al sandbox del sistema operativo.

Las pruebas dinámicas o destructivas solo deben ejecutarse contra local/sandbox/staging autorizado y sin datos reales que puedan dañarse.
