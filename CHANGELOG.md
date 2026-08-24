# Changelog

## V0.5.4

- Corrige el falso estado `DEGRADED` observado con Hermes Agent v0.20.0: la tabla Rich de `hermes plugins list` puede truncar `sabas-secure-development` como `sabas-secure-devel…` aunque el plugin esté realmente `enabled`.
- Usa `hermes plugins list --plain --no-bundled` como comprobación primaria de discovery/estado cuando la CLI lo soporta; la tabla con debug queda como evidencia secundaria y para detectar plugins built-in.
- Acepta como evidencia adicional un `plugins enable` con código 0 y mensaje inequívoco `already enabled`/`enabled`, evitando falsos negativos por formato visual de consola.
- Añade una marca `.sabas-managed-plugin.json` para acreditar propiedad del plugin en futuras actualizaciones/desinstalaciones.
- Limpia de forma conservadora copias antiguas del plugin Sabas en homes Hermes alternativos únicamente cuando puede demostrar que son copias gestionadas por Sabas; siempre crea backup antes de retirarlas.
- El smoke test Windows reproduce expresamente la regresión real: salida gráfica truncada con `…` y salida `--plain --no-bundled` con el nombre completo.
- Mantiene la política de no conceder `--allow-tool-override`; los hooks Sabas no necesitan sustituir herramientas built-in de Hermes.

## V0.5.3

- Corrige `NativeCommandError` en Windows PowerShell 5.1 cuando Hermes escribe mensajes informativos/debug por `stderr` aunque termine correctamente con código 0.
- Todas las llamadas Hermes que capturan salida pasan por `Invoke-SabasNativeCapture`, que decide por el **exit code real** y trata `stdout/stderr` como datos, no como excepciones.
- El wrapper restaura `ErrorActionPreference`, variables de entorno temporales y codificación después de cada proceso para no contaminar la sesión de PowerShell.
- Añade un preflight `Native stderr compatibility probe` que reproduce `stderr + exit code 0` en la propia sesión de Windows **antes de modificar Codex/Hermes**.
- Intenta usar UTF-8 durante llamadas nativas para evitar mojibake en mensajes modernos de Hermes.
- `Diagnose-Hermes.ps1` usa la misma estrategia tolerante a stderr.
- El smoke test de Windows ahora obliga a la CLI Hermes simulada a escribir mensajes DEBUG por `stderr` con código 0, reproduciendo exactamente la regresión observada antes de permitir un PASS de CI.
- Añade autopruebas estáticas que impiden reintroducir capturas directas `@(& hermes ... 2>&1)` en el instalador principal.
- Las autopruebas desactivan la escritura de bytecode (`sys.dont_write_bytecode`) para no crear `__pycache__` que invalide `MANIFEST.sha256` al reinstalar desde la misma carpeta.

## V0.5.2

- Sustituye la suposición de una única ruta Hermes por resolución adaptativa: `hermes config path`, `HERMES_HOME`, discovery real con `HERMES_PLUGINS_DEBUG`, `%LOCALAPPDATA%\hermes` y fallback Windows heredado `~\.hermes`.
- Si discovery confirma un home distinto al inicialmente calculado, autocorrige el destino y replica allí las skills propias antes de instalar dependencias externas.
- Cambia la activación del plugin: detecta capacidades con `hermes plugins -h`, intenta `enable`, ejecuta discovery debug y reintenta `enable` una vez si el catálogo se refresca después.
- El plugin resuelve su propio HERMES_HOME a partir de `__file__`, evitando que una diferencia entre layouts Windows rompa la localización de `security_context.py`.
- Mantiene un `plugin.yaml` deliberadamente mínimo (`name`, `version`, `description`) para maximizar compatibilidad con releases antiguas.
- La integración Hermes deja de abortar toda la instalación ante incompatibilidades de plugin: continúa en modo `DEGRADED` y guarda `hermes-plugin-diagnostic.txt` sin leer secretos.
- Los fallos de red/upstream al instalar las 20 skills externas quedan aislados y se reportan explícitamente como `FAILED` sin borrar el núcleo ya instalado.
- Endurece `pre_tool_call`: usa `block` como contrato mínimo cross-version tanto para operaciones catastróficas como para comandos sensibles y rutas de secretos/configuración; las operaciones legítimas bloqueadas se ejecutan manualmente tras revisión.
- `pre_verify` se registra de forma tolerante: una versión de Hermes que aún no conozca ese hook no rompe la carga completa del plugin.
- Intenta activar el plugin oficial `security-guidance` cuando discovery demuestra que la versión instalada lo ofrece.
- Añade `Diagnose-Hermes.ps1` para versión, perfil, config path, capacidades y plugin discovery.
- Amplía las autopruebas para evitar regresiones en rutas Hermes, `plugins doctor`, manifiesto y contrato del Tool Guard.
- Mantiene UTF-8 con BOM en scripts PowerShell para Windows PowerShell 5.1.

## 0.4.2

- Corrige la validación del campo `name` de skills externas para Windows PowerShell 5.1, eliminando una expresión regular con escape incompatible que provocaba `ParserError`.
- Añade un preflight con el parser nativo de PowerShell sobre todos los `.ps1` del paquete antes de modificar Codex.
- Evita que un error sintáctico en un instalador auxiliar pueda dejar una instalación parcialmente aplicada.
- Mantiene intactos el lockfile, el commit fijado y el allowlist defensivo de skills externas.

## 0.4.1

- Corrige el arranque del validador en Windows PowerShell 5.1/entornos donde `py.exe` abría el REPL interactivo (`>>>`) en lugar de recibir `validate_bundle.py`.
- Sustituye la combinación de splatting + argumento posicional por invocaciones explícitas `py -3 <script>` / `python <script>`.
- No cambia la política de seguridad, el lockfile externo ni el comportamiento de los gates de V0.4.

## 0.4.0

- El veredicto final queda ligado a `SABAS_SECURITY_FINGERPRINT`, una SHA-256 del estado actual del cambio; cualquier modificación posterior invalida el recibo del gate.
- El instalador ejecuta el validador del bundle antes de modificar `$HOME/.agents` o `CODEX_HOME`.
- `usuario-torpe-qa` pasa a tener una copia de soporte autosuficiente con perfiles, catálogo, WordPress y plantillas; si ya existe, solo se completan auxiliares ausentes sin sobrescribir la versión del usuario.
- El perfil externo recomendado por el instalador principal pasa a `all`: 20 skills defensivas allowlisted, no el catálogo completo.
- El hook Stop corrige la lectura del esquema estructurado de `security_context.py`, respeta `CODEX_HOME` en POSIX y escribe `hooks.json` mediante reemplazo controlado.
- El desinstalador puede retirar de forma selectiva el bloque AGENTS, el hook y solo la copia demostrablemente administrada de `usuario-torpe-qa`, preservando configuración ajena.
- El validador comprueba también la copia de soporte y sintaxis Python sin generar bytecode.
- Integración preferente con Codex Security oficial cuando está disponible, sin convertirlo en dependencia de la extensión IDE.
- Nuevo guardrail opcional `Stop` basado en hooks de Codex para exigir una pasada de seguridad en cambios R2+ antes de cerrar.
- Marcador machine-readable `SABAS_SECURITY_VERDICT` para coordinar el hook con el orquestador sin falsos PASS.
- Instalador global compatible con `CODEX_HOME`.
- Tratamiento explícito de `AGENTS.override.md`: el gate se añade también al override no vacío para evitar que la prioridad global lo deje inactivo.
- Merge conservador de `hooks.json`, backup previo y requisito documentado de revisión/confianza del hook.
- El instalador externo lee commit y allowlists exclusivamente desde `EXTERNAL-SKILLS.lock.json`, eliminando doble fuente de verdad.
- Nuevo plugin `sabas-secure-development` con tres skills enfocadas.
- Nuevo modelo de riesgo R0–R4 y modos FAST/STANDARD/DEEP/RELEASE.
- Nuevo modelo de amenazas persistente por repositorio.
- Baseline práctico alineado con OWASP ASVS 5.0.0.
- Gate de seguridad con veredicto PASS / PASS WITH WARNINGS / BLOCKED.
- Distinción entre findings introducidos, afectados y preexistentes.
- Aceptación de riesgo formal, trazable y con expiración.
- Supply-chain pinning de las skills externas a un commit concreto.
- Perfiles de instalación externa web/api/devsecops/all.
- Inventario determinista del repositorio mediante `security_context.py`.
- Validador de estructura del bundle mediante `validate_bundle.py`.
- Integración reforzada con `usuario-torpe-qa` sin duplicar esa skill.
- Política de retest y pruebas de regresión para vulnerabilidades corregidas.
- Política específica para secretos: redactar, eliminar y rotar si fueron reales.
- Revisión de historial de Git cuando exista indicio de secreto versionado.
- Controles de supply chain, lockfiles, SBOM y CI según riesgo.
- Detección de archivos nuevos no versionados para que el gate no dependa de haber ejecutado `git add`.
- Escalado R4 ante patrones de credenciales literales sin exponer el valor detectado.
- Escalado R3 específico para acceso SQL y sinks DOM sensibles en contenido añadido.
- `EXTERNAL-SKILLS.lock.json` como fuente machine-readable de commit y allowlists externas.
- Validación previa de nombres de skills externas antes de modificar la instalación local.
- Metadatos `.sabas-source-lock.json` para conservar procedencia y commit por skill externa.
- Protección frente a reemplazo silencioso de skills externas de otra procedencia; requiere `-Force`.
- Limpieza garantizada del clon temporal externo incluso cuando una validación falle.
- Ruta de instalación diferenciada para VS Code/Codex IDE: skills locales directas, sin depender del soporte de plugins de la extensión.

## 0.2.0

- Primera integración de seguridad defensiva con `usuario-torpe-qa`.
- Routing de skills web y externas.
- Checklist de seguridad y gate básico Critical/High.
