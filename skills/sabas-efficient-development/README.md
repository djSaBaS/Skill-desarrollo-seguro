# Sabas Efficient Development

Skill portable para reducir trabajo innecesario de un agente de programación sin sacrificar corrección, pruebas ni seguridad.

Su objetivo no es hacer que el modelo "piense menos", sino evitar consumo inútil: exploraciones completas del repositorio, relecturas, pruebas globales prematuras, escaneos duplicados, subagentes innecesarios, trabajo en segundo plano y refactors fuera de alcance.

La versión **0.2.0** añade un **Scope Compiler**: cuando el usuario da una instrucción demasiado amplia, la skill la convierte internamente en un primer lote pequeño y verificable antes de empezar a usar herramientas.

Por ejemplo:

`"corrige los errores de Sonar" -> usar hallazgos existentes -> 1 causa raíz o máximo 3 incidencias relacionadas -> máximo 5 archivos de producción -> pruebas dirigidas -> informar -> STOP`

De esta forma un prompt amplio no se interpreta automáticamente como permiso para volver a auditar todo el repositorio.

## Flujo

`evidencia conocida -> acotar prompt -> búsqueda dirigida -> working set pequeño -> cambio mínimo -> prueba dirigida -> ampliar solo si hace falta -> parar`

Incluye tres modos:

- `ECO`: cambios locales y bien acotados.
- `STANDARD`: bugs o funcionalidades que afectan a varios componentes cercanos.
- `DEEP`: arquitectura, problemas sistémicos, migraciones, releases o auditorías completas solicitadas explícitamente.

`DEEP` no se activa simplemente porque el repositorio sea grande, exista un hallazgo de seguridad o haya disponible un scanner potente.

## Qué evita por defecto

Para una corrección local la skill intenta evitar:

- escaneos completos o `deep scan` no solicitados;
- repetir SonarQube, CI, lint o auditorías que ya aportaron evidencia suficiente;
- agentes/subagentes paralelos innecesarios;
- procesos largos en segundo plano;
- suites completas antes de una prueba dirigida;
- relectura de archivos ya comprendidos;
- continuar automáticamente con el siguiente lote después de terminar uno.

Si ampliar el alcance es realmente necesario para resolver correctamente el problema, la skill debe explicarlo antes de hacerlo salvo que el usuario ya haya pedido trabajo autónomo amplio.

## Compatibilidad con desarrollo seguro

Puede instalarse junto a `sabas-secure-qa`.

No sustituye ni rebaja sus controles. Si la skill de seguridad exige una revisión, test o gate determinado, se ejecuta. `sabas-efficient-development` únicamente evita duplicar lecturas, análisis y herramientas dentro de ese proceso.

En remediaciones normales prioriza revisión enfocada en el cambio. Los escaneos profundos de repositorio quedan reservados para release, riesgo alto real, petición expresa o evidencia que justifique ampliar la investigación.

## Compatibilidad

El núcleo es un único `SKILL.md` basado en el estándar abierto Agent Skills y está pensado para:

- OpenAI Codex;
- Google Antigravity IDE;
- Hermes Agent;
- ChatGPT Skills cuando esté disponible en la cuenta.

## Instalación recomendada desde este repositorio

Para que la misma versión quede coordinada con el resto del bundle usa el setup portable:

```powershell
cd scripts

# Codex
.\Setup-SabasSecureDev.ps1 -Target Codex

# Hermes
.\Setup-SabasSecureDev.ps1 -Target Hermes

# Google Antigravity IDE
.\Setup-SabasSecureDev.ps1 -Target Antigravity
```

El setup conserva backups antes de sustituir una copia Sabas existente.

## Instalación manual en Codex

### Windows PowerShell

```powershell
$SkillDir = Join-Path $HOME '.agents\skills\sabas-efficient-development'
New-Item -ItemType Directory -Force -Path $SkillDir | Out-Null
Invoke-WebRequest `
    -Uri 'https://raw.githubusercontent.com/djSaBaS/Skill-desarrollo-seguro/main/skills/sabas-efficient-development/SKILL.md' `
    -OutFile (Join-Path $SkillDir 'SKILL.md')
```

### Linux / macOS

```bash
mkdir -p ~/.agents/skills/sabas-efficient-development
curl -fsSL \
  https://raw.githubusercontent.com/djSaBaS/Skill-desarrollo-seguro/main/skills/sabas-efficient-development/SKILL.md \
  -o ~/.agents/skills/sabas-efficient-development/SKILL.md
```

## Instalación en Google Antigravity IDE

Antigravity IDE descubre skills globales en:

```text
~/.gemini/config/skills/<skill-folder>/SKILL.md
```

y skills del workspace en:

```text
<workspace>/.agents/skills/<skill-folder>/SKILL.md
```

### Global para todos tus proyectos — Windows PowerShell

```powershell
$SkillDir = Join-Path $HOME '.gemini\config\skills\sabas-efficient-development'
New-Item -ItemType Directory -Force -Path $SkillDir | Out-Null
Invoke-WebRequest `
    -Uri 'https://raw.githubusercontent.com/djSaBaS/Skill-desarrollo-seguro/main/skills/sabas-efficient-development/SKILL.md' `
    -OutFile (Join-Path $SkillDir 'SKILL.md')
```

### Global para todos tus proyectos — Linux / macOS

```bash
mkdir -p ~/.gemini/config/skills/sabas-efficient-development
curl -fsSL \
  https://raw.githubusercontent.com/djSaBaS/Skill-desarrollo-seguro/main/skills/sabas-efficient-development/SKILL.md \
  -o ~/.gemini/config/skills/sabas-efficient-development/SKILL.md
```

Antigravity usa divulgación progresiva: inicialmente conoce el nombre y la descripción de la skill y carga su cuerpo completo cuando resulta relevante.

Antigravity CLI mantiene un árbol global diferente (`~/.gemini/antigravity-cli/skills/`). Para compartir una skill entre IDE y CLI, la opción más portable es mantenerla dentro del workspace en `.agents/skills/`.

Consulta `../../ANTIGRAVITY.md` para la integración completa del bundle.

## Instalación en Hermes Agent

```bash
hermes skills install https://raw.githubusercontent.com/djSaBaS/Skill-desarrollo-seguro/main/skills/sabas-efficient-development/SKILL.md
```

Comprueba después:

```bash
hermes skills list
```

## Actualización portable

Para actualizar desde el repositorio oficial:

```powershell
cd scripts

# Codex
.\Update-SabasSecureDev.ps1 -Target Codex

# Hermes
.\Update-SabasSecureDev.ps1 -Target Hermes

# Antigravity IDE
.\Update-SabasSecureDev.ps1 -Target Antigravity
```

El actualizador descarga el bundle público, lo valida y ejecuta el setup en modo `Update`.

## Qué no puede garantizar

La skill puede reducir consumo evitable, pero no controla directamente las cuotas del producto ni el coste interno del modelo. El uso final seguirá dependiendo del modelo, nivel de razonamiento, tamaño real de la tarea, herramientas utilizadas y cantidad de contexto necesaria.

Si un problema exige análisis amplio, la skill debe priorizar una solución correcta y segura antes que el ahorro.
