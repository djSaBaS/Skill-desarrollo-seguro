# Integración con Codex Security oficial

## Objetivo

Usa Codex Security como una capa adicional de alta calidad cuando esté disponible. No sustituye las comprobaciones deterministas de secretos, dependencias, tests, baseline manual ni `usuario-torpe-qa`.

## Detección

Antes de intentar usar esta capa, comprueba si la sesión expone las skills/comandos del plugin oficial Codex Security. No inventes disponibilidad.

Capacidades relevantes documentadas por OpenAI:

- revisión de cambios/diff para detectar regresiones de seguridad;
- escaneo estándar del repositorio;
- escaneo profundo para revisiones de mayor profundidad;
- triage y remediación de findings.

La extensión IDE puede no exponer plugins aunque las skills personales de este bundle sí estén disponibles. Si la capa oficial no está accesible en la superficie actual, registra `NOT AVAILABLE` y continúa con las demás capas. No conviertas su ausencia en un `BLOCKED` por sí sola salvo que una política del repositorio lo exija expresamente.

## Routing recomendado

### R0/R1 — FAST

No invoques Codex Security únicamente por rutina. Usa pruebas y revisión focalizada.

### R2 — STANDARD

Si la revisión de cambios oficial está disponible y el diff toca lógica ejecutable relevante, úsala como segunda opinión después de entender el diff.

### R3 — DEEP

Prefiere la revisión oficial de cambios sobre el diff actual, además de las comprobaciones específicas del stack. Valida manualmente cualquier finding antes de bloquear o corregir.

### R4 / RELEASE

Cuando esté disponible y el alcance lo permita:

1. usa revisión de cambios para regresiones introducidas por el diff;
2. usa escaneo de repositorio para cobertura más amplia;
3. usa deep scan para componentes críticos, revisiones preproducción de alto riesgo o cuando el threat model indique superficie compleja;
4. correlaciona findings con SAST/SCA/secret scanning y evidencia de runtime;
5. no copies severidades ciegamente: reclasifica por impacto y alcanzabilidad reales.

## Evitar duplicación inútil

- Si Codex Security ya produjo un finding confirmado, no ejecutes cinco skills externas equivalentes salvo que aporten evidencia distinta.
- Mantén Gitleaks/secret scanning, SCA y tests deterministas aunque exista un análisis por modelo.
- Usa skills externas específicas para cubrir huecos concretos: BOLA, mass assignment, JWT, CORS, supply chain, etc.
- Usa `usuario-torpe-qa` para comportamiento real, estados, recuperación y mal uso; Codex Security no sustituye esa perspectiva dinámica.

## Tratamiento del resultado

Cada finding oficial debe pasar por el mismo sistema de `CONFIRMED`, `HIGH-CONFIDENCE`, `POTENTIAL`, `FALSE-POSITIVE` o `NOT-VERIFIED` del orquestador.

Un informe limpio de Codex Security no demuestra ausencia de vulnerabilidades. Registra la capa como ejecutada y continúa con las comprobaciones obligatorias del modo seleccionado.
