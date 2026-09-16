# Sabas Efficient Development

Skill portable para reducir trabajo innecesario de un agente de programación sin sacrificar corrección, pruebas ni seguridad.

La versión **0.2.0** añade un **Scope Compiler**: una petición amplia se convierte primero en un lote pequeño y verificable antes de abrir archivos, lanzar herramientas o iniciar agentes auxiliares.

Ejemplo:

`"corrige los errores de Sonar" -> reutilizar hallazgos existentes -> 1 causa raíz o máximo 3 incidencias relacionadas -> máximo 5 archivos de producción -> pruebas dirigidas -> informar -> STOP`

El objetivo no es hacer que el modelo "piense menos", sino evitar consumo inútil: exploraciones completas, relecturas, scans duplicados, suites globales prematuras, subagentes innecesarios, procesos en segundo plano y refactors fuera de alcance.

## Flujo

`evidencia conocida -> acotar prompt -> búsqueda dirigida -> working set pequeño -> cambio mínimo -> prueba dirigida -> ampliar solo si hace falta -> parar`

Modos:

- `ECO`: cambio local, error concreto, archivo/símbolo conocido.
- `STANDARD`: varios componentes cercanos o dependencia local incierta.
- `DEEP`: arquitectura, problema sistémico, migración, release o auditoría completa realmente solicitada.

`DEEP` no se activa solo porque el repositorio sea grande, exista un hallazgo de seguridad o haya disponible un scanner potente.

## Límites por defecto para peticiones abiertas

Salvo que el usuario pida trabajo autónomo amplio:

- una causa raíz o hasta tres hallazgos estrechamente relacionados;
- hasta cinco archivos de producción salvo necesidad de corrección;
- pruebas directamente relacionadas;
- sin `deep scan`, auditoría global, agentes paralelos o procesos en segundo plano por defecto;
- detenerse al terminar el lote e informar del siguiente recomendado.

Los límites son presupuestos de trabajo, no excusas para entregar una corrección incompleta. Si la solución correcta exige ampliar el alcance, el agente debe justificarlo.

## Compatibilidad con Sabas Secure QA

`sabas-efficient-development` no sustituye ni rebaja los gates de `sabas-secure-qa`.

Cuando seguridad exige una comprobación, se ejecuta. La capa de eficiencia evita duplicar scans, releer contexto conocido o convertir una remediación concreta en una auditoría completa sin necesidad.

## Compatibilidad

El `SKILL.md` sigue el estándar Agent Skills y está pensado para:

- OpenAI Codex;
- Google Antigravity IDE;
- Hermes Agent;
- ChatGPT Skills cuando esa capacidad esté disponible.

## Instalación recomendada desde el bundle

Desde `scripts`:

```powershell
.\Setup-SabasSecureDev.ps1
```

El selector permite instalar o actualizar Codex, Hermes, Google Antigravity IDE o los tres.

Para una instalación no interactiva:

```powershell
# Codex
.\Setup-SabasSecureDev.ps1 -Target Codex -UpdateGlobalAgents -InstallCompletionHook

# Hermes
.\Setup-SabasSecureDev.ps1 -Target Hermes

# Google Antigravity IDE
.\Setup-SabasSecureDev.ps1 -Target Antigravity

# Todos
.\Setup-SabasSecureDev.ps1 -Target All -UpdateGlobalAgents -InstallCompletionHook
```

## Google Antigravity IDE

Antigravity usa Agent Skills con divulgación progresiva.

La ruta global oficial es:

```text
~/.gemini/config/skills/<skill-name>/SKILL.md
```

La ruta por proyecto es:

```text
<workspace>/.agents/skills/<skill-name>/SKILL.md
```

Para instalar esta skill manualmente de forma global en Windows:

```powershell
$SkillDir = Join-Path $HOME '.gemini\config\skills\sabas-efficient-development'
New-Item -ItemType Directory -Force -Path $SkillDir | Out-Null
Invoke-WebRequest `
    -Uri 'https://raw.githubusercontent.com/djSaBaS/Skill-desarrollo-seguro/main/skills/sabas-efficient-development/SKILL.md' `
    -OutFile (Join-Path $SkillDir 'SKILL.md')
```

En Linux/macOS:

```bash
mkdir -p ~/.gemini/config/skills/sabas-efficient-development
curl -fsSL \
  https://raw.githubusercontent.com/djSaBaS/Skill-desarrollo-seguro/main/skills/sabas-efficient-development/SKILL.md \
  -o ~/.gemini/config/skills/sabas-efficient-development/SKILL.md
```

Antigravity CLI mantiene un árbol global distinto (`~/.gemini/antigravity-cli/skills/`). El instalador portable de este repositorio configura **Antigravity IDE**; no instala hooks ni plugins en Antigravity CLI.

## Codex

Codex descubre la skill global en:

```text
~/.agents/skills/sabas-efficient-development/SKILL.md
```

El setup portable la instala aunque el motor de seguridad V0.5.4 original solo administrase las tres skills de seguridad.

## Hermes

El setup localiza el árbol efectivo de skills de Hermes y añade `sabas-efficient-development` junto a las skills de seguridad. No sustituye la lógica de discovery del plugin nativo de Hermes.

## Actualización

Para actualizar desde GitHub sin descargar manualmente un nuevo ZIP:

```powershell
# Codex
.\Update-SabasSecureDev.ps1 -Target Codex -UpdateGlobalAgents -InstallCompletionHook

# Hermes
.\Update-SabasSecureDev.ps1 -Target Hermes

# Antigravity IDE
.\Update-SabasSecureDev.ps1 -Target Antigravity

# Todos
.\Update-SabasSecureDev.ps1 -Target All -UpdateGlobalAgents -InstallCompletionHook
```

El actualizador descarga el bundle, valida su manifiesto/autopruebas y reutiliza el setup idempotente.

## Qué no puede garantizar

La skill reduce consumo evitable, pero no controla directamente las cuotas del producto ni el coste interno del modelo. El uso final depende del modelo, razonamiento, tamaño real de la tarea, herramientas y contexto.

Si un problema exige análisis amplio, la corrección y seguridad tienen prioridad sobre el ahorro.
