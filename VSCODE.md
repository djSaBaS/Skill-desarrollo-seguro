# Uso con Codex en VS Code

Las skills instaladas en `$HOME/.agents/skills` están pensadas para ser visibles desde Codex IDE además de Codex CLI. La extensión IDE no usa el sistema de plugins, por lo que para VS Code debes ejecutar el instalador PowerShell de este paquete, que copia las skills directamente a esa ubicación personal.

## Instalación recomendada

Desde la carpeta `scripts` del paquete:

```powershell
./Install-SabasSecureDev.ps1 -Target Codex -UpdateGlobalAgents -InstallExternalSkills -ExternalProfile all -InstallCompletionHook
```

El perfil `all` instala solo las 20 skills defensivas allowlisted y fijadas a commit, no el catálogo completo. El instalador valida el bundle antes de tocar tu configuración y preserva una versión ya existente de `usuario-torpe-qa`.

## Flujo diario recomendado

1. Trabaja normalmente con Codex en el repositorio.
2. Mantén el bloque de `AGENTS.md` global activo para que la seguridad forme parte del criterio de cierre; si usas `AGENTS.override.md`, el instalador conserva el gate también allí.
3. Para cambios normales, deja que `sabas-secure-qa` seleccione automáticamente `FAST`, `STANDARD` o `DEEP`.
4. Para autenticación, permisos, paneles administrativos, uploads, APIs, datos sensibles, pagos, secretos, webhooks o cambios de CI, el orquestador debe escalar a `DEEP` o `RELEASE`.
5. Antes de producción, pide explícitamente modo `RELEASE`.
6. Cuando exista una aplicación ejecutable en local/staging, permite `usuario-torpe-qa` únicamente después de confirmar que el entorno está controlado.

## Invocaciones útiles

```text
$sabas-security-bootstrap Analiza este repositorio y prepara su baseline de seguridad.
```

```text
$sabas-threat-model Crea o actualiza el modelo de amenazas de este proyecto.
```

```text
$sabas-secure-qa Revisa el diff actual y corrige los problemas bloqueantes.
```

```text
$sabas-secure-qa Modo RELEASE: valida este proyecto antes de desplegarlo.
```

## Importante

El orquestador no debe interpretar que la ausencia de una herramienta equivale a un resultado limpio. Si no puede ejecutar un scanner o una prueba dinámica, el informe debe decir `NOT VERIFIED` y continuar con el mejor análisis disponible.


## Guardrail de cierre

Si instalaste `-InstallCompletionHook`, Codex evalúa un hook `Stop`. Cuando el clasificador detecta un cambio R2/R3/R4 y el último mensaje no contiene un veredicto de `sabas-secure-qa` junto a `SABAS_SECURITY_FINGERPRINT` coincidente con el estado actual, el hook pide una única continuación para ejecutar el gate. Un cambio posterior invalida la huella anterior. Revisa/confía el hook con `/hooks`.

## Codex Security oficial y VS Code

El orquestador detecta esa capa cuando la superficie actual la expone. No la presupone: en una sesión IDE donde no esté accesible, la revisión continúa mediante las skills personales, herramientas del repositorio y `usuario-torpe-qa`. Para scans oficiales más amplios puedes abrir el mismo repositorio en Codex Desktop/CLI y ejecutar la capa Codex Security allí.
