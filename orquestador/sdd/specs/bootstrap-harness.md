# Bootstrap Harness Spec

Objetivo: crear o actualizar un `.hebrinex/` operativo sin copiar contexto de otro proyecto ni documentacion personal.

Fuente local libre: carpeta con `PROJECT_BINDING.yaml` y `binding_mode: source_template`. Si no existe, proponer descargar el repo fuente. Una fuente libre se copia; nunca se usa directamente como autoridad.

Al copiar fuente a `<project_root>/.hebrinex/`, excluir siempre:
- `infoHebri.md`
- `.git/`
- archivos temporales o logs locales

Luego actualizar `PROJECT_BINDING.yaml` a `binding_mode: bound`, `harness_version: "0.8.5"`, `project_root`, `project_name`, `repo_remote`, `bound_at` y `harness_instance_id`.

Entrada minima post-bootstrap: `PROJECT_BINDING.yaml`, `session-pin.md`, `memory-registry.yaml`, `memory-routing.yaml`, `context-budget.yaml` y entrypoint aplicable.

No declarar bootstrap completo sin validar `init.sh`, `.gitignore` del consumidor y ausencia de `infoHebri.md` en `.hebrinex/` consumidor.