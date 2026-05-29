---
description: "Migrar cualquier .hebrinex previo a Hebri-AI-Harness 0.7.0 sin contaminar proyectos"
---

# Migracion a Hebri-AI-Harness 0.7.0

Actua como interprete operativo del harness. No implementes nada hasta presentar preflight y esperar `SI`.

## Objetivo

Migrar el `.hebrinex/` del proyecto activo a Hebri-AI-Harness 0.7.0, preservando contexto local del proyecto y evitando usar un harness de otra carpeta como autoridad operativa.

## Reglas duras

1. El `.hebrinex/` valido debe vivir dentro de la raiz del proyecto activo.
2. Si no existe `.hebrinex/`, buscar una fuente local libre con `PROJECT_BINDING.yaml` y `binding_mode: source_template`.
3. Si existe fuente libre, proponer copiarla a `<project_root>/.hebrinex/` y vincularla.
4. Si no existe fuente libre, proponer bajar obligatoriamente `https://github.com/HebrineX/Hebri-AI-Harness` y vincularlo al proyecto.
5. Nunca operar desde un harness local externo.
6. `.hebrinex/` debe estar en `.gitignore` del proyecto consumidor.
7. Preservar archivos locales de proyecto: `PROGRESS.md`, `orquestador/context/`, specs locales, progress/cycles, registry, locks, approvals, gates y reports.
8. No sobrescribir contexto local sin mostrar comparacion y recibir `SI`.

## Paso 1 - Auditoria read-only

Leer:

- `<project_root>/.hebrinex/HARNESS_VERSION` si existe.
- `<project_root>/.hebrinex/PROJECT_BINDING.yaml` si existe.
- `<project_root>/.hebrinex/AGENTS.md`.
- `<project_root>/.hebrinex/orquestador/method/session-contract.md`.
- `.gitignore` del proyecto.
- estado de archivos locales del harness que contienen contexto del proyecto.

Reportar:

```text
Auditoria de migracion:
- Project root:
- Harness path:
- Version actual:
- Binding actual:
- .gitignore contiene .hebrinex/: si | no
- Contexto local a preservar:
- Archivos de infraestructura a actualizar:
- Riesgos:
- Siguiente accion:
- Requiere SI: si
```

## Paso 2 - Plan de migracion

Separar:

- **Preservar:** contexto y progreso real del proyecto.
- **Actualizar:** contrato, method, policies, templates, prompts y version.
- **Agregar:** `PROJECT_BINDING.yaml`, `harness-resolution.md`, `reentry-checklist.md`, prompt de migracion si falta.
- **Regularizar:** `.gitignore`, estado/binding, placeholders, approvals/gates si aplica.

## Paso 3 - Preflight obligatorio

Antes de copiar, editar o descargar:

```text
Preflight:
- Approval ID: APR-MIGRATE-HARNESS-070
- Modo:
- Rol solicitante: leader
- Accion propuesta:
- CWD:
- Project root:
- Harness path:
- Binding status:
- Read-set:
- Write-set:
- External write scope:
- Comando/tool:
- Red/git/externo:
- Riesgo:
- Verificacion:
- Evidencia esperada:
- Invalidacion:
- Requiere SI: si
```

## Paso 4 - Binding

La copia final del proyecto debe tener:

```yaml
schema: hebrinex.project_binding
version: "0.1"
harness_version: "0.7.0"
binding_mode: bound
harness_instance_id: "HBX-[timestamp-o-id]"
project_name: "[nombre]"
project_root: "[ruta absoluta]"
repo_remote: "[url o none]"
source_repo: "https://github.com/HebrineX/Hebri-AI-Harness"
created_at: "[fecha]"
bound_at: "[fecha]"
```

## Paso 5 - Verificacion

Ejecutar solo con aprobacion:

- `./.hebrinex/init.sh` o equivalente desde el harness del proyecto.
- Verificar que el binding coincide.
- Verificar que `.hebrinex/` no esta trackeado por git.
- Verificar que no se copiaron ciclos/specs de otro proyecto.

## Salida esperada

Entregar:

```text
Migracion 0.7.0:
- Estado:
- Archivos preservados:
- Archivos actualizados/agregados:
- Binding:
- Validacion:
- Riesgos pendientes:
- Siguiente paso:
```
