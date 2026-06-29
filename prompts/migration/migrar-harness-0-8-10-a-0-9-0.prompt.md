---
id: hebrinex.migrar_harness_0_8_10_a_0_9_0
version: 1.0.0
schema_version: 1
description: "Migrar un proyecto con Hebri-AI-Harness 0.8.10 a 0.9.0 sin perder estado local ni contaminar evidencia."
---

# Migracion Hebri-AI-Harness 0.8.10 -> 0.9.0

Usar cuando un proyecto consumidor ya tiene `.hebrinex/` version `0.8.10` y se quiere actualizar a `0.9.0`.

## Contrato inicial obligatorio

Antes de copiar, editar, ejecutar comandos, usar git/red o cambiar estado:

1. Declarar contrato de sesion.
2. Leer `.hebrinex/PROJECT_BINDING.yaml`.
3. Leer `.hebrinex/orquestador/memory/local/session-pin.md`.
4. Leer `.hebrinex/orquestador/memory/memory-registry.yaml`.
5. Leer `.hebrinex/orquestador/memory/memory-routing.yaml`.
6. Leer `.hebrinex/orquestador/context-budget.yaml`.
7. Leer `.hebrinex/orquestador/sdd/progress/state.yaml` y `registry.yaml`.
8. Confirmar que el binding es `bound` y que `project_root` coincide.

Si el harness es `source_template`, no migrar como proyecto consumidor; operar como fuente.

## Preflight minimo

```text
Approval ID: MIGRATE-HAH-0-8-10-TO-0-9-0
Accion propuesta: migrar .hebrinex de 0.8.10 a 0.9.0 preservando estado local.
CWD: [project_root]
Read-set: .hebrinex/PROJECT_BINDING.yaml, state.yaml, registry.yaml, memory-routing, memory-registry, session-pin, manifest viejo y fuente 0.9.0
Write-set: .hebrinex/ excepto estado/evidencia preservada segun plan; backups en ubicacion declarada
Comando/tool: copia controlada + validadores 0.9.0
Red/git/externo: declarar si aplica
Riesgo: medio; cambio estructural de rutas de prompts y registries canonicos
Verificacion: validate-harness.ps1 -RunNegativeTests, init.sh, check-adapter-drift.ps1, busqueda de rutas viejas
Evidencia esperada: validadores OK, manifest coherente, prompt-registry y registry-index presentes
Requiere SI: SI
```

## Cambios estructurales de 0.9.0

- `prompts/` deja de ser carpeta plana.
- Los prompts se agrupan en `adapters/`, `audit/`, `bootstrap/`, `migration/`, `roles/`, `runtime/`, `session/` y `workflows/`.
- Aparecen registries canonicos:
  - `orquestador/registry-index.yaml`
  - `orquestador/prompt-registry.yaml`
  - `orquestador/adapter-registry.yaml`
  - `orquestador/context-profile-registry.yaml`
  - `orquestador/gate-registry.yaml`
  - `orquestador/policy-registry.yaml`
  - `orquestador/template-registry.yaml`
- `orquestador/source-of-truth.md` declara fuente canonica vs artefactos derivados.
- `state.yaml` source-template queda alineado a modo default `automatico`.

## Preservar siempre

No sobrescribir sin merge explicito:

- `.hebrinex/PROJECT_BINDING.yaml` salvo `harness_version`.
- `.hebrinex/orquestador/sdd/progress/state.yaml`.
- `.hebrinex/orquestador/sdd/progress/registry.yaml`.
- `.hebrinex/orquestador/sdd/progress/cycles/**`.
- `.hebrinex/orquestador/sdd/progress/approvals/**`.
- `.hebrinex/orquestador/sdd/progress/locks/**`.
- `.hebrinex/orquestador/memory/daily/**`.
- `.hebrinex/orquestador/memory/cycle/**`.
- `.hebrinex/orquestador/memory/project/**`.
- Evidencia, reports y verification matrices existentes.

`infoHebri.md` sigue excluido materialmente de operacion y no debe entrar al manifest.

## Procedimiento

1. Crear backup o snapshot declarado de `.hebrinex/`.
2. Copiar archivos operativos 0.9.0 desde fuente libre validada.
3. Preservar y mergear estado local, registry, cycles, locks, approvals y memoria local/proyecto.
4. Actualizar `PROJECT_BINDING.yaml` a `harness_version: "0.9.0"` manteniendo `binding_mode: bound`, `project_root`, `project_name`, `repo_remote`, `bound_at` e `harness_instance_id`.
5. Reconciliar referencias antiguas a prompts planos:
   - `prompts/lider.prompt.md` -> `prompts/roles/lider.prompt.md`
   - `prompts/implementer.prompt.md` -> `prompts/roles/implementer.prompt.md`
   - `prompts/reviewer.prompt.md` -> `prompts/roles/reviewer.prompt.md`
   - `prompts/spec-author.prompt.md` -> `prompts/roles/spec-author.prompt.md`
   - `prompts/preset-*.prompt.md` -> `prompts/adapters/preset-*.prompt.md`
   - `prompts/harness-runtime.prompt.md` -> `prompts/runtime/harness-runtime.prompt.md`
   - prompts de migracion/reconstruccion -> `prompts/migration/`
6. Confirmar que `orquestador/harness-manifest.txt` incluye registries y prompts nuevos.
7. Ejecutar validaciones.

## Validacion obligatoria

```text
.hebrinex/scripts/validate-harness.ps1 -Root .hebrinex -RunNegativeTests
.hebrinex/scripts/check-adapter-drift.ps1 -Root .hebrinex
bash -lc 'cd [project_root]/.hebrinex && ./init.sh'
```

Buscar rutas obsoletas:

```text
prompts/[A-Za-z0-9_-]+.prompt.md
prompts/preset-
0.8.10
```

Las referencias a `0.8.10` solo son aceptables como historial, notas de migracion o contexto del prompt actual. No deben quedar como version operativa.

## Salida esperada

```text
Migracion 0.8.10 -> 0.9.0:
- Binding:
- Project root:
- Archivos preservados:
- Archivos actualizados:
- Validadores:
- Rutas obsoletas encontradas/corregidas:
- Evidencia:
- Riesgo residual:
- Requiere accion humana:
```

No declarar `done` si state/registry/gates/evidencia no quedaron coherentes o si algun validador falla.
