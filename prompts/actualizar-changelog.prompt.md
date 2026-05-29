# Prompt: Actualizar Changelog con Reconstruccion de Evidencia

Usa este prompt cuando el operador pida completar, ordenar, corregir o versionar `CHANGELOG.md`, release notes o documentacion historica.

## Rol

Actua bajo el harness como:

- chat visible: interprete
- leader visible: coordinador del flujo
- `auditor(profile: release)`: obligatorio antes de escribir
- `reporter(profile: technical|operator)`: opcional para presentar el resultado

No escribas el changelog de forma directa.

## Objetivo

Reconstruir la historia del cambio desde evidencia local, proponer una matriz versionada y recien despues pedir aprobacion para editar.

## Pasos Obligatorios

1. Declarar contrato de sesion y validar `PROJECT_BINDING.yaml`.
2. Leer `orquestador/method/evidence-reconstruction.md`.
3. Leer `orquestador/method/changelog-policy.md`.
4. Definir scope: version, rango historico o problema a reconstruir.
5. Leer, si existen:
   - `CHANGELOG.md`
   - `PROGRESS.md`
   - `orquestador/sdd/progress/state.yaml`
   - `orquestador/sdd/progress/registry.yaml`
   - `orquestador/sdd/progress/registry.md`
   - gate logs, final reports y audit trails relevantes
   - `git log --oneline --decorate --date=short`
   - `git show --stat` de commits relevantes
6. Completar checklist y matriz:
   - `orquestador/sdd/progress/templates/changelog-reconstruction-checklist.md`
   - `orquestador/sdd/progress/templates/release-history-matrix.yaml`
7. Presentar:
   - hechos observados
   - inferencias
   - contradicciones
   - gaps
   - propuesta de versiones
8. Pedir `SI` antes de escribir.
9. Editar solo despues de aprobacion.
10. Validar que cada entrada del changelog sale de la matriz.

## Bloqueos

Bloquear y reportar si:

- `git log`, `PROGRESS.md` o registry existen pero no fueron leidos;
- hay eventos sin version y no se puede proponer version sintetica;
- el operador menciona un hecho que no aparece en fuentes y no hay evidencia externa;
- CI/deploy/migracion se estan colapsando sin justificacion;
- el changelog resultante no puede auditarse contra evidencia.

## Formato de Respuesta Antes de Escribir

```text
Estado:
- Scope:
- Fuentes leidas:
- Fuentes faltantes:

Hechos observados:
- ...

Inferencias:
- ...

Contradicciones/Gaps:
- ...

Propuesta de changelog:
- ...

Preflight:
- Approval ID:
- Write-set:
- Riesgo:
- Verificacion:
- Requiere SI: si
```
