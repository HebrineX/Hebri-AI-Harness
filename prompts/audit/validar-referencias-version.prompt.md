# Prompt: Validar Referencias y Version

Usar antes de cerrar una version del harness o migracion.

1. Declarar contrato y validar binding.
2. Leer `orquestador/method/reference-drift-policy.md`.
3. Leer `HARNESS_VERSION`, `PROJECT_BINDING.yaml`, `README.md`, `CHANGELOG.md`, `init.sh` y prompts de migracion.
4. Completar `orquestador/sdd/progress/templates/reference-drift-matrix.yaml`.
5. Clasificar referencias como `operative`, `historical`, `example` o `stale`.
6. Bloquear si una referencia operativa diverge de la version canonica.
