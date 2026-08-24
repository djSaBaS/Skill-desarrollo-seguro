# Security Threat Model

> Este fichero contiene contexto de seguridad persistente del proyecto. No guardes contraseñas, tokens, cookies, claves ni secretos.

## 1. Alcance y despliegue

- Aplicación/sistema:
- Tipo de despliegue:
- Entornos existentes:
- Componentes fuera de alcance:

## 2. Usuarios, roles y permisos

| Rol | Puede hacer | No debe poder hacer | Datos accesibles |
|---|---|---|---|
| | | | |

## 3. Activos que debemos proteger

| Activo | Sensibilidad | Impacto si se expone/modifica/destruye |
|---|---|---|
| | | |

## 4. Datos sensibles

- Datos personales:
- Credenciales/tokens:
- Datos financieros:
- Documentos/archivos:
- Otros:

## 5. Puntos de entrada

- Formularios:
- API/REST/GraphQL:
- AJAX:
- Webhooks:
- Uploads/importaciones:
- Tareas CLI/cron:
- Administración:

## 6. Límites de confianza

Describe dónde cambian los niveles de confianza, por ejemplo navegador → servidor, usuario → admin, aplicación → proveedor externo, plugin → WordPress core o API → base de datos.

| Origen | Destino | Datos | Controles esperados |
|---|---|---|---|
| | | | |

## 7. Autenticación y sesión

- Mecanismo de login:
- Recuperación de contraseña:
- MFA si existe:
- Gestión de sesión/cookies/tokens:
- Cierre/revocación:

## 8. Autorización

- Fuente de roles/permisos:
- Comprobación server-side:
- Reglas de ownership:
- Aislamiento multi-tenant si existe:

## 9. Persistencia y base de datos

- Motor:
- Acceso a datos:
- Transacciones críticas:
- Migraciones:
- Backups/restore:

## 10. Integraciones externas

| Servicio | Dirección del flujo | Datos compartidos | Autenticación | Riesgo principal |
|---|---|---|---|---|
| | | | | |

## 11. Operaciones de alto impacto

Enumera acciones como eliminar, publicar, enviar correo/SMS, cobrar, exportar datos, cambiar permisos, restablecer contraseñas o ejecutar jobs.

## 12. Casos de abuso prioritarios

| ID | Caso de abuso | Actor | Impacto | Control esperado | Prueba |
|---|---|---|---|---|---|
| TM-001 | | | | | |

## 13. Supuestos de seguridad

- 

## 14. Riesgos conocidos y deuda de seguridad

- 

## 15. Historial de actualización

| Fecha | Cambio del modelo | Motivo |
|---|---|---|
| | | |
