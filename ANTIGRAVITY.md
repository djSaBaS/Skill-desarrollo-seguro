# Google Antigravity — Sabas Skills

Este repositorio soporta **Google Antigravity IDE** mediante el estándar Agent Skills.

## Rutas oficiales

Antigravity IDE descubre skills globales en:

```text
~/.gemini/config/skills/<skill-folder>/SKILL.md
```

y skills del workspace en:

```text
<workspace>/.agents/skills/<skill-folder>/SKILL.md
```

Antigravity mantiene compatibilidad heredada con `.agent/skills`, pero este proyecto usa `.agents/skills`.

## Instalación global recomendada

Desde `scripts`:

```powershell
.\Setup-SabasSecureDev.ps1 -Target Antigravity
```

Se instalarán:

```text
~/.gemini/config/skills/
├── sabas-efficient-development/
├── sabas-secure-qa/
├── sabas-threat-model/
├── sabas-security-bootstrap/
└── usuario-torpe-qa/
```

El setup ejecuta primero las autopruebas del bundle y conserva backups de las skills Sabas existentes.

## Instalación para un solo proyecto

Si prefieres que las skills vivan dentro del repositorio, copia las carpetas elegidas a:

```text
<workspace>/.agents/skills/
```

Ejemplo:

```text
mi-proyecto/
└── .agents/
    └── skills/
        ├── sabas-efficient-development/
        │   └── SKILL.md
        └── sabas-secure-qa/
            └── SKILL.md
```

Las referencias, scripts y assets de una skill deben copiarse junto a su `SKILL.md` cuando existan.

## Cómo las usa Antigravity

Antigravity aplica divulgación progresiva:

1. al iniciar la conversación conoce el nombre y la descripción;
2. si la skill parece relevante, carga su `SKILL.md`;
3. durante la ejecución puede consultar los recursos incluidos en esa carpeta.

Esto encaja especialmente bien con `sabas-efficient-development`, porque la skill no necesita estar entera en el contexto hasta que una tarea de desarrollo la activa.

Puedes mencionar una skill por nombre para forzar su uso, por ejemplo:

```text
Usa sabas-efficient-development y corrige el siguiente lote de Sonar.
```

## Scope Compiler en Antigravity

Para un prompt amplio como:

```text
corrige los errores de Sonar
```

la skill debe convertirlo en un primer lote acotado antes de usar herramientas:

```text
hallazgos existentes
      ↓
1 causa raíz / hasta 3 incidencias relacionadas
      ↓
working set pequeño
      ↓
cambio mínimo
      ↓
pruebas relacionadas
      ↓
STOP
```

No debe iniciar por defecto:

- `deep scan` completo;
- auditoría de todo el repositorio;
- agentes/subagentes paralelos;
- procesos largos en segundo plano;
- suites globales antes de pruebas dirigidas.

## Seguridad en Antigravity

La integración de este repositorio con Antigravity IDE es **declarativa**.

No instala:

- el Stop Hook de Codex;
- el plugin nativo de Hermes;
- hooks adicionales de Antigravity;
- MCPs;
- subagentes en segundo plano.

`sabas-secure-qa` sigue funcionando como protocolo de trabajo, pero los guardrails nativos específicos de Codex/Hermes no se simulan en Antigravity.

## Actualización

Desde `scripts`:

```powershell
.\Update-SabasSecureDev.ps1 -Target Antigravity
```

El actualizador descarga la referencia pública indicada (`main` por defecto), ejecuta las autopruebas y sustituye únicamente las skills Sabas administradas.

## Antigravity CLI

Antigravity CLI usa un árbol global distinto:

```text
~/.gemini/antigravity-cli/skills/
```

La documentación de CLI permite skills globales en ese árbol y skills del workspace en `.agents/skills/`.

El setup portable de este repositorio configura **Antigravity IDE** en `~/.gemini/config/skills/`. No copia automáticamente a `~/.gemini/antigravity-cli/skills/` porque el empaquetado global del CLI y el del IDE no son idénticos.

Para compartir la misma skill con CLI, la opción más portable es mantenerla dentro del proyecto en:

```text
.agents/skills/<skill-folder>/
```

## Verificación

Después de instalar, comprueba que exista:

```text
~/.gemini/config/skills/sabas-efficient-development/SKILL.md
```

y reinicia/recarga Antigravity para forzar un nuevo discovery de skills si la sesión ya estaba abierta.

## Referencias oficiales

La implementación sigue la documentación actual de Google Antigravity para Agent Skills:

- [Agent Skills (IDE)](https://antigravity.google/docs/skills): skills globales en `~/.gemini/config/skills/`, workspace en `.agents/skills/` y divulgación progresiva de `SKILL.md`;
- [Plugins & Skills (CLI)](https://www.antigravity.google/docs/cli/plugins): skills globales de CLI en `~/.gemini/antigravity-cli/skills/`.
