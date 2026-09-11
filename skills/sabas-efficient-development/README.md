# Sabas Efficient Development

Skill portable para reducir trabajo innecesario de un agente de programación sin sacrificar corrección, pruebas ni seguridad.

Su objetivo no es hacer que el modelo "piense menos", sino evitar consumo inútil: exploraciones completas del repositorio, relecturas, pruebas globales prematuras, refactors fuera de alcance y respuestas demasiado largas.

El núcleo es un único `SKILL.md` compatible con el estándar abierto Agent Skills. Está diseñado para usarse con **OpenAI Codex**, **Hermes Agent** y **ChatGPT Skills** cuando esa función esté disponible en la cuenta.

## Qué cambia al trabajar

La skill fuerza un flujo sencillo:

`evidencia conocida -> búsqueda dirigida -> working set pequeño -> cambio mínimo -> prueba dirigida -> ampliar solo si hace falta -> parar`

Incluye tres modos de trabajo:

- `ECO`: cambios locales y bien acotados.
- `STANDARD`: funcionalidades o bugs que afectan a varios componentes.
- `DEEP`: arquitectura, problemas sistémicos, release o trabajo que realmente exige análisis amplio.

`DEEP` no se activa simplemente porque el repositorio sea grande.

## Compatibilidad con desarrollo seguro

Puede instalarse junto a `sabas-secure-qa`.

No sustituye ni rebaja sus controles. Si la skill de seguridad exige una revisión, test o gate determinado, se ejecuta. `sabas-efficient-development` únicamente evita duplicar lecturas, análisis y herramientas dentro de ese proceso.

## Instalación en Codex

### Windows PowerShell

```powershell
$SkillDir = Join-Path $HOME '.agents\skills\sabas-efficient-development'
New-Item -ItemType Directory -Force -Path $SkillDir | Out-Null
Invoke-WebRequest `
    -Uri 'https://raw.githubusercontent.com/djSaBaS/Skill-desarrollo-seguro/main/skills/sabas-efficient-development/SKILL.md' `
    -OutFile (Join-Path $SkillDir 'SKILL.md')
```

Después inicia una sesión nueva de Codex o recarga el entorno para que vuelva a descubrir las skills.

### Linux / macOS

```bash
mkdir -p ~/.agents/skills/sabas-efficient-development
curl -fsSL \
  https://raw.githubusercontent.com/djSaBaS/Skill-desarrollo-seguro/main/skills/sabas-efficient-development/SKILL.md \
  -o ~/.agents/skills/sabas-efficient-development/SKILL.md
```

## Instalación en Hermes Agent

Hermes puede instalar una skill de un solo archivo directamente desde URL:

```bash
hermes skills install https://raw.githubusercontent.com/djSaBaS/Skill-desarrollo-seguro/main/skills/sabas-efficient-development/SKILL.md
```

Comprueba después:

```bash
hermes skills list
```

En una sesión ya abierta puede ser necesario iniciar una nueva sesión para que el listado de skills se regenere.

## Uso en ChatGPT web

Cuando tu cuenta/espacio de trabajo tenga habilitadas las Skills:

1. Abre `Plugins`.
2. Entra en `Skills`.
3. Selecciona `Crear`.
4. Elige `Cargar desde tu computadora`.
5. Descarga y carga el `SKILL.md` de esta carpeta.

ChatGPT puede activar una skill relevante automáticamente o puedes seleccionarla explícitamente.

La disponibilidad de Skills en ChatGPT depende actualmente del plan, del workspace y de la interfaz. Si tu cuenta no muestra `Plugins > Skills`, el mismo `SKILL.md` se puede adjuntar a un proyecto/chat y pedir que se aplique como instrucciones de trabajo, pero en ese caso no queda instalado como skill persistente.

## Actualización

Codex, Windows:

```powershell
Invoke-WebRequest `
    -Uri 'https://raw.githubusercontent.com/djSaBaS/Skill-desarrollo-seguro/main/skills/sabas-efficient-development/SKILL.md' `
    -OutFile (Join-Path $HOME '.agents\skills\sabas-efficient-development\SKILL.md')
```

Hermes:

```bash
hermes skills update sabas-efficient-development
```

## Qué no puede garantizar

La skill puede reducir consumo evitable, pero no controla directamente las cuotas del producto ni el coste interno de un modelo. El uso final seguirá dependiendo del modelo, nivel de razonamiento, tamaño real de la tarea, herramientas utilizadas y cantidad de contexto necesaria.

Si un problema exige análisis amplio, la skill debe priorizar la solución correcta antes que el ahorro.
