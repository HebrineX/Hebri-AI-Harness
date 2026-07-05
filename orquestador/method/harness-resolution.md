# Harness Resolution

Version: 0.13.0

Un proyecto solo opera con el `.hebrinex` dentro de su raiz y vinculado por `PROJECT_BINDING.yaml`.

Operation: buscar `.hebrinex/`, validar binding y `project_root`. Si falta o no coincide, detenerse.

Bootstrap: buscar fuente libre `source_template`, copiarla a `<project_root>/.hebrinex/` excluyendo `infoHebri.md`, `.git/` y temporales, vincular como `bound`. Si no hay fuente libre, proponer descarga. Todo efecto requiere preflight + `SI`.

Un harness externo solo puede ser fuente de copia, nunca autoridad operativa.