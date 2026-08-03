# Harness Resolution

Version: 0.17.0

Un proyecto solo opera con el `.hebrinex` dentro de su raiz y vinculado por `PROJECT_BINDING.yaml`.

Operation: buscar `.hebrinex/`, validar binding y `project_root`. Si falta o no coincide, detenerse.

Bootstrap: buscar fuente libre `source_template`, leer `SHARED_MANIFEST.yaml`, materializar `instance_dirs` como copia real y permitir que `shared_dirs` se compartan por junction/symlink si el consumidor lo soporta. Si `SHARED_MANIFEST.yaml` no existe, usar fallback legacy 0.16.x: copiar el manifest estructural completo excluyendo `infoHebri.md`, `.git/`, `.codex/` y temporales. Luego vincular como `bound`. Todo efecto requiere preflight + `SI`.

Contrato de cache compartida: `SHARED_MANIFEST.yaml` es la fuente de verdad para consumidores. `shared_dirs` contiene rutas relativas a la raiz `.hebrinex` que pueden compartirse. `instance_dirs` contiene rutas que siempre deben ser copia real por proyecto. `instance_path_map` declara compatibilidad entre rutas legacy 0.16.x y rutas canonicas bajo `instance/`; una CLI consumidora debe preservar contenido existente de esas rutas al migrar un proyecto bound.

Migracion 0.16.x -> 0.17.0: antes del primer write, crear backup con el mecanismo `migration-bound-update-*`. Preservar `PROJECT_BINDING.yaml`, `bound_at`, `project_name`, `harness_instance_id`, estado SDD, approvals, locks, ciclos, memoria local/proyecto/ciclo/diaria/completa, reportes/backups de migracion, runtime generado y overrides locales de MCP. No romper `binding_mode: bound`.

Un harness externo solo puede ser fuente de copia, nunca autoridad operativa.
