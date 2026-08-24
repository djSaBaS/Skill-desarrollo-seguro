---
name: usuario-torpe-qa
description: Prueba aplicaciones web y plugins WordPress simulando usuarios inexpertos, impulsivos y destructivos en entornos locales o de pruebas. Úsala para detectar fallos funcionales, validación, recuperación, permisos, UX, AJAX e integridad de datos mediante interacción real con navegador. No usar en producción.
version: 1.0.0
metadata:
  hermes:
    tags: [qa, testing, navegador, wordpress, ux, pruebas-destructivas]
    category: software-development
---

# Usuario Torpe QA

## Propósito

Ejecuta pruebas exploratorias y reproducibles sobre la interfaz de una aplicación web o un plugin de WordPress. Simula a una persona con pocos conocimientos digitales que no lee, se equivoca, insiste, pulsa repetidamente, introduce datos incorrectos y realiza acciones destructivas accidentales.

El objetivo no es comportarse de forma aleatoria sin criterio. El objetivo es descubrir si la aplicación:

- previene acciones inválidas;
- mantiene la integridad de los datos;
- informa de forma comprensible;
- permite recuperarse de errores;
- evita duplicados y envíos repetidos;
- aplica correctamente permisos y roles;
- soporta navegación torpe, recargas y varias pestañas;
- conserva un estado coherente después de acciones incorrectas;
- registra o manifiesta errores técnicos observables.

## Cuándo usar esta skill

Úsala cuando el usuario pida probar mediante navegador:

- una aplicación web;
- un formulario público o privado;
- un panel de administración;
- un plugin de WordPress;
- flujos AJAX;
- altas, ediciones, búsquedas o eliminaciones;
- permisos y roles visibles desde la interfaz;
- facilidad de uso, prevención de errores o capacidad de recuperación.

No la uses para revisar únicamente código fuente, hacer pentesting ofensivo, probar infraestructura sin interfaz o ejecutar pruebas sobre producción.

## Principios obligatorios

1. Interactúa realmente con la aplicación mediante la herramienta de navegador disponible.
2. No afirmes que una acción ocurrió si no pudo observarse o verificarse.
3. Distingue siempre entre hecho observado, resultado esperado e inferencia.
4. No corrijas automáticamente la entrada antes de enviarla.
5. No interpretes la interfaz como un usuario experto.
6. No leas necesariamente ayudas, tooltips o instrucciones antes de actuar.
7. No detengas la exploración tras el primer error recuperable.
8. Verifica el estado real después de guardar, eliminar, recargar o volver atrás.
9. Intenta reproducir cada incidencia al menos una segunda vez cuando sea seguro y posible.
10. No modifiques código ni apliques correcciones durante la auditoría salvo petición explícita posterior.
11. Usa exclusivamente datos ficticios identificables como datos de prueba.
12. Registra toda incidencia en Markdown con pasos reproducibles y propuesta concreta.

## Puerta de seguridad obligatoria

Antes de abrir la aplicación o ejecutar cualquier acción, solicita confirmación explícita con este sentido:

> Confirma que la URL pertenece a un entorno local o de pruebas controlado, que no contiene datos reales y que está permitido crear, modificar y eliminar información. Estas pruebas pueden ser destructivas.

No comiences mientras la confirmación sea ambigua, parcial o indirecta.

Solicita además estos datos cuando no estén disponibles:

- URL inicial;
- credenciales o método de acceso;
- roles que deben probarse;
- alcance funcional o pantallas prioritarias;
- navegador y resolución;
- si se probarán otros tamaños de pantalla o solo el actual;
- restricciones conocidas, si existen.

La opción habitual para dispositivos es usar únicamente navegador y resolución actuales, pero debe preguntarse.

### Señales de posible producción

Detente y pide aclaración si observas cualquiera de estas señales:

- dominio público real no identificado como staging;
- clientes, alumnos, empleados, pedidos o usuarios reales;
- correos, teléfonos o direcciones reales;
- pasarela de pago activa fuera de modo sandbox;
- facturación, webhooks o integraciones externas reales;
- claves o secretos de producción;
- correos salientes hacia destinatarios reales;
- datos cuya eliminación pueda afectar a terceros.

La confirmación inicial no invalida esta comprobación continua.

## Preparación de la ejecución

Genera un identificador único con este formato:

`UTQA-AAAAMMDD-HHMMSS`

Úsalo en nombres, títulos, descripciones y notas de los datos creados. Usa dominios reservados como `example.test` y valores inequívocamente ficticios.

Ejemplo:

- Nombre: `Usuario Torpe UTQA-20260802-143522`
- Correo: `utqa-20260802-143522@example.test`
- Título: `Registro de prueba UTQA-20260802-143522`
- Descripción: `Dato ficticio creado por usuario-torpe-qa`

Antes de las pruebas caóticas:

1. Registra URL, fecha, rol, navegador, resolución y alcance.
2. Comprueba que la sesión corresponde al rol esperado.
3. Identifica las acciones que guardan, publican, envían o eliminan.
4. Realiza un recorrido normal mínimo para conocer el comportamiento base.
5. Anota los datos preexistentes que no deben confundirse con los creados por la ejecución.

## Selección de perfiles

Carga `references/perfiles.md` cuando necesites decidir cómo actuar. Alterna perfiles durante la auditoría, pero identifica cuál provocó cada incidencia.

Perfiles mínimos:

- usuario que no lee;
- usuario impaciente;
- usuario sin experiencia digital;
- usuario destructivo accidental;
- administrador confundido;
- usuario que intenta recuperarse.

No conviertas el perfil en ruido aleatorio. Cada acción debe representar un error humano plausible.

## Procedimiento de prueba

### Fase 1. Reconocimiento funcional

Haz un recorrido superficial para localizar:

- navegación principal;
- formularios y campos obligatorios;
- botones primarios y secundarios;
- acciones destructivas;
- guardados automáticos;
- mensajes y validaciones;
- filtros, tablas y paginación;
- procesos AJAX o indicadores de carga;
- áreas restringidas por rol;
- dependencias entre registros.

No completes todavía una auditoría experta ni revises el código fuente.

### Fase 2. Camino correcto de referencia

Ejecuta al menos una vez el flujo principal de forma correcta. Registra:

- pasos;
- resultado visible;
- datos realmente persistidos;
- mensajes recibidos;
- tiempo o bloqueo perceptible si es relevante.

Si el camino correcto ya falla, regístralo como incidencia base antes de continuar.

### Fase 3. Mal uso controlado

Consulta `references/catalogo-pruebas.md` y selecciona escenarios relevantes para la pantalla actual. Incluye, cuando sean aplicables:

- campos vacíos, parciales o fuera de formato;
- espacios, textos largos, caracteres especiales y pegado de contenido;
- doble clic y pulsaciones repetidas;
- reenvío durante una carga;
- recarga, atrás y adelante en estados intermedios;
- dos pestañas editando el mismo registro;
- duplicación de datos;
- acciones masivas sin selección;
- filtros contradictorios;
- accesos directos mediante URL;
- cambios y eliminaciones con roles insuficientes;
- eliminación, restauración y edición posterior de registros eliminados;
- configuración inválida o incompatible en administración.

No ejecutes cargas masivas ni bucles ilimitados. Las pruebas repetidas deben ser suficientes para revelar el comportamiento sin provocar una denegación de servicio.

### Fase 4. Recuperación

Después de cada error significativo, prueba si una persona puede continuar sin ayuda técnica:

- corregir el dato;
- volver atrás;
- recargar;
- reabrir el registro;
- cancelar y empezar de nuevo;
- restaurar un elemento;
- iniciar una nueva sesión;
- repetir el flujo correctamente.

Registra si se conserva información útil, se pierde trabajo, aparece un bloqueo o queda un estado incoherente.

### Fase 5. Verificación técnica observable

Aunque el alcance sea la experiencia del usuario, registra cuando la herramienta permita observar:

- errores JavaScript;
- respuestas HTTP fallidas;
- errores AJAX;
- carga infinita;
- pantalla en blanco;
- mensajes técnicos expuestos;
- solicitudes duplicadas;
- diferencias entre interfaz y datos persistidos.

No hagas afirmaciones sobre logs, base de datos o servidor si no tienes acceso real a ellos.

### Fase 6. Reproducción mínima

Para cada incidencia:

1. Restablece el estado cuando sea posible.
2. Repite el problema.
3. Reduce la secuencia a los pasos mínimos.
4. Conserva evidencia suficiente.
5. Identifica el perfil de usuario que la provoca.
6. Describe una prueba de regresión recomendada.

Si no puede reproducirse, márcala como `No reproducida` y no la presentes como confirmada.

### Fase 7. Limpieza

Al finalizar:

- localiza los datos con el identificador UTQA;
- elimina o restaura los datos creados según corresponda;
- no elimines evidencia necesaria sin registrarla antes;
- lista los datos que no pudieron limpiarse;
- confirma el estado final de la aplicación.

## Criterios de incidencia

Registra un problema cuando observes alguno de estos comportamientos:

- resultado funcional incorrecto;
- datos inválidos aceptados;
- datos válidos rechazados sin explicación;
- duplicados o guardados parciales;
- pérdida o corrupción aparente de datos;
- ausencia de confirmación de una acción;
- mensaje técnico o incomprensible;
- imposibilidad de recuperarse;
- acción destructiva insuficientemente protegida;
- permiso incorrecto;
- estado inconsistente entre pantallas;
- botón bloqueado o carga infinita;
- error JavaScript, HTTP o AJAX observable;
- interfaz que induce de forma razonable al error.

No registres como bug una preferencia personal sin impacto demostrable. Puede anotarse como observación UX si existe riesgo plausible.

## Clasificación

Categorías:

- `Bug funcional`
- `Validación`
- `Recuperación`
- `Integridad de datos`
- `Permisos`
- `UX`
- `Feedback`
- `Concurrencia`
- `Acción destructiva`
- `Error técnico`

Severidades:

- `Crítica`: pérdida grave, acceso no autorizado, daño general o bloqueo completo.
- `Alta`: función principal inutilizable o datos incoherentes con impacto importante.
- `Media`: fallo relevante pero recuperable o limitado a un flujo secundario.
- `Baja`: confusión, defecto menor o fricción sin pérdida significativa.
- `Observación`: riesgo o mejora razonable sin bug confirmado.

Evalúa severidad según impacto, alcance, probabilidad y capacidad de recuperación. Un error de consola aislado no es automáticamente grave.

## Evidencia

Captura, cuando la herramienta lo permita:

- URL y pantalla;
- texto exacto del mensaje;
- valor introducido;
- estado anterior y posterior;
- captura de pantalla;
- estado de red o consola relevante;
- identificador del registro creado;
- rol utilizado.

No incluyas contraseñas, tokens, cookies, claves ni datos sensibles en el informe.

## Informe obligatorio

Genera un informe Markdown basado en `templates/informe.md` y una tabla de incidencias basada en `templates/tabla-incidencias.md`.

Nombre recomendado:

`informe-usuario-torpe-qa-<IDENTIFICADOR>.md`

El informe debe contener:

- datos de ejecución;
- resumen ejecutivo;
- cobertura realizada y no realizada;
- tabla de incidencias;
- detalle reproducible de cada problema;
- comportamientos correctos observados;
- datos creados, eliminados y pendientes de limpieza;
- propuestas de corrección priorizadas;
- pruebas de regresión recomendadas;
- limitaciones de la auditoría.

Las propuestas deben ser específicas. Evita frases vacías como “mejorar la validación”. Indica qué validar, dónde, qué feedback mostrar, cómo conservar el estado y qué prueba automatizada añadir.

## Salida durante la ejecución

Mantén un registro breve de progreso. Informa cuando:

- termine el reconocimiento;
- se encuentre una incidencia crítica o alta;
- una prueba destructiva cambie datos;
- aparezca una señal de posible producción;
- una limitación impida verificar un resultado.

No satures al usuario con cada clic.

## Uso con WordPress

Carga `references/wordpress.md` para pruebas específicas. Como mínimo contempla:

- administración y frontend;
- roles y capacidades;
- ajustes del plugin;
- formularios y shortcodes;
- acciones masivas;
- AJAX y nonces observables;
- activación y desactivación si forma parte del alcance autorizado;
- creación, edición, papelera, restauración y borrado permanente;
- acceso directo a páginas administrativas mediante URL.

No edites archivos, base de datos ni configuración del servidor durante esta auditoría salvo autorización explícita adicional.

## Compatibilidad de navegador

Usa la herramienta visual disponible en Codex o Hermes. Adapta nombres de acciones sin inventar comandos. Si existe Playwright u otra automatización:

- úsala para repetir recorridos y recopilar evidencia;
- no dependas exclusivamente de selectores frágiles;
- prioriza roles, etiquetas y texto accesible;
- no conviertas automáticamente todos los hallazgos en tests sin validar la reproducción.

Si no hay navegador operativo, detente e informa de que la skill no puede ejecutar pruebas reales. No sustituyas la interacción por una simulación narrativa.

## Modos

### Exploratorio

Busca estados imprevistos mediante errores humanos plausibles. Es el modo predeterminado.

### Reproducible

Repite un hallazgo, minimiza pasos y prepara una prueba de regresión. Úsalo después de encontrar una incidencia.

### Completo

Combina reconocimiento, camino correcto, exploración, recuperación, reproducción y limpieza.

## Cierre

Antes de terminar, responde explícitamente:

- qué se probó;
- qué no pudo probarse;
- cuántas incidencias hay por severidad;
- si quedan datos de prueba;
- dónde se guardó el informe;
- cuál es la prioridad de corrección.
