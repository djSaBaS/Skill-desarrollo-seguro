# Catálogo de pruebas — Usuario Torpe QA

Selecciona únicamente escenarios aplicables al flujo real. Evita cargas masivas, bucles ilimitados y cualquier comportamiento que pueda convertirse en denegación de servicio.

## Entradas y validación

- Vacío total y campos obligatorios omitidos.
- Espacios iniciales/finales y solo espacios.
- Longitudes 0, 1, máximo permitido, máximo + 1 y texto razonablemente largo.
- Caracteres Unicode, acentos, emojis y signos habituales.
- Formatos plausibles pero inválidos: email, teléfono, fecha, número, decimal y código postal.
- Pegado de contenido con saltos de línea o espacios invisibles cuando sea pertinente.
- Valores duplicados cuando el dominio exige unicidad.

## Envíos y concurrencia humana

- Doble clic en guardar/enviar.
- Pulsaciones repetidas durante una carga.
- Volver a enviar tras timeout o feedback ambiguo.
- Recargar después de enviar.
- Atrás/adelante del navegador en un flujo con persistencia.
- Dos pestañas editando el mismo registro cuando sea seguro.

## Navegación y orden incorrecto

- Abrir una URL interna directamente sin pasar por la pantalla previa.
- Saltar pasos de wizard mediante navegación disponible.
- Usar botones secundarios antes de completar requisitos.
- Cambiar filtros/paginación durante una edición.
- Abandonar y volver al flujo.

## Autenticación y permisos observables

- Sesión caducada durante una acción.
- Usuario autenticado con rol insuficiente intenta una ruta o acción visible/directa.
- Cambio de rol autorizado durante la sesión de pruebas.
- Confirmar que una UI oculta no se considere por sí sola control de autorización.

## CRUD y acciones destructivas

- Crear con datos mínimos válidos.
- Editar un registro recién creado.
- Cancelar una edición y verificar persistencia.
- Eliminar únicamente datos ficticios creados para la prueba.
- Restaurar desde papelera cuando exista.
- Intentar volver a editar un elemento eliminado.
- Acción masiva sin selección y con selección mínima ficticia.

## Red y feedback

- Observar errores HTTP/AJAX disponibles en la herramienta.
- Detectar spinner infinito o botón bloqueado.
- Verificar que el mensaje de error no exponga detalles técnicos sensibles.
- Cuando la herramienta lo permita sin afectar terceros, simular una respuesta lenta o fallo temporal y comprobar recuperación.

## Evidencia mínima por hallazgo

- Rol y URL.
- Estado inicial.
- Datos ficticios introducidos.
- Pasos mínimos.
- Resultado observado y resultado esperado.
- Evidencia de consola/red solo cuando exista acceso real.
- Segundo intento de reproducción cuando sea seguro.
