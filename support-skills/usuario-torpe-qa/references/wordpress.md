# Pruebas específicas de WordPress — Usuario Torpe QA

Aplica esta referencia únicamente a plugins, themes o flujos WordPress en un entorno local/staging confirmado.

## Administración

- Verifica acceso con los roles autorizados para la prueba.
- Prueba páginas administrativas mediante navegación normal y URL directa.
- Comprueba acciones individuales y masivas con selección vacía y mínima.
- Prueba ajustes inválidos o incompatibles sin introducir secretos reales.
- Activa/desactiva el plugin solo si forma parte del alcance explícitamente autorizado.

## Formularios, shortcodes y frontend

- Prueba formularios correctos e incorrectos.
- Comprueba doble envío, recarga, atrás y recuperación.
- Verifica mensajes visibles y conservación razonable del estado.
- Comprueba shortcodes/bloques en páginas de prueba cuando estén en alcance.

## AJAX y REST observables

- Observa respuestas 4xx/5xx, duplicados y cargas infinitas.
- Prueba acciones con sesión caducada o rol insuficiente cuando sea posible mediante la interfaz.
- Un nonce válido no demuestra autorización; registra únicamente el comportamiento observable y deja la revisión de capacidades al análisis de código.

## CRUD de contenido de prueba

- Crea datos claramente marcados con `UTQA-*`.
- Edita, mueve a papelera, restaura y borra permanentemente solo los registros ficticios creados por la auditoría.
- Verifica que no queden registros huérfanos o estados incoherentes observables.

## Límites

- No edites archivos, base de datos ni configuración del servidor durante esta auditoría salvo autorización explícita adicional.
- No uses datos personales reales, claves, correos reales ni servicios externos de producción.
