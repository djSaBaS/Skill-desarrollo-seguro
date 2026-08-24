# Security Risk Acceptance Register

Este registro evita silenciar hallazgos sin trazabilidad. Una aceptación no convierte una vulnerabilidad en segura; documenta temporalmente que el riesgo es conocido.

## Reglas

- No incluir secretos ni datos sensibles.
- Cada excepción debe tener ID estable, alcance exacto, motivo, compensaciones y fecha de expiración.
- `Critical` requiere una decisión explícita del usuario/responsable y nunca debe asumirse por el agente.
- `High` debe tener justificación y expiración concreta.
- Una excepción expirada vuelve a estar abierta.
- Los `nosec`, suppressions, allowlists o exclusiones de scanner deberían referenciar el ID de este registro cuando sea posible.

## Riesgos aceptados

| ID | Finding | Severidad | Alcance exacto | Motivo | Control compensatorio | Aprobado por | Fecha | Expira | Estado |
|---|---|---|---|---|---|---|---|---|---|
| | | | | | | | | | |
