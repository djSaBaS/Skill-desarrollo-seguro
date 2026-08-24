<!-- SABAS-SECURE-DEVELOPMENT:START -->
## Secure development gate

- Para cualquier creación, modificación, refactorización o revisión de código ejecutable, aplica `sabas-secure-qa` antes de considerar el trabajo terminado.
- Omite el gate únicamente para cambios puramente documentales, de texto o formato sin impacto ejecutable.
- Usa la clasificación de riesgo R0-R4 de la skill y permite que escale automáticamente el modo de revisión.
- Autenticación, autorización, roles, permisos, sesiones, recuperación de contraseña, administración, APIs sensibles, subida/descarga de archivos, SQL, webhooks, pagos, secretos, criptografía, multi-tenant, CI/CD y ejecución de comandos son cambios de alto riesgo y no deben cerrarse con una revisión rápida.
- No consideres `herramienta no disponible` como `sin vulnerabilidades`; marca esa comprobación como `NOT VERIFIED`.
- No des por finalizado un cambio que introduzca o afecte un finding Critical/High sin corregir, salvo aceptación de riesgo explícita y trazable según `sabas-secure-qa`.
- Un secreto real detectado bloquea el cierre hasta eliminarlo del código y documentar su rotación cuando haya podido quedar expuesto.
- Añade una prueba de regresión para cada vulnerabilidad corregida cuando sea técnicamente razonable.
- Si Codex Security oficial está disponible en la superficie actual, úsalo como capa adicional según el modo de riesgo; su ausencia en la extensión IDE no equivale a un fallo por sí sola.
- Ejecuta `usuario-torpe-qa` para flujos de interfaz relevantes únicamente en local, sandbox o staging autorizado y respetando su confirmación obligatoria.
- La auditoría de `usuario-torpe-qa` se ejecuta antes de corregir sus hallazgos; después el orquestador puede corregir y repetir las pruebas.
- Antes de una entrega a producción, ejecuta el modo `RELEASE` de `sabas-secure-qa`.
- Cuando el gate se haya ejecutado para el cambio actual, vuelve a ejecutar `security_context.py`, termina con exactamente un `SABAS_SECURITY_VERDICT: PASS`, `PASS WITH WARNINGS` o `BLOCKED` y añade `SABAS_SECURITY_FINGERPRINT: <gate_fingerprint>` con la huella recién calculada; si el código cambia después, esa huella queda invalidada y el gate debe reevaluarse.
<!-- SABAS-SECURE-DEVELOPMENT:END -->
