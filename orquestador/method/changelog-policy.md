# Changelog Policy

Esta politica existe para evitar cambios de changelog, release notes o documentacion de version basados en memoria parcial, resumen de chat o instrucciones incompletas del operador.

## Principio

El changelog es un artefacto derivado de evidencia. No se edita hasta reconstruir la historia minima del cambio.

## Cuando Aplica

Aplica antes de editar:

- `CHANGELOG.md`
- release notes
- README con version actual o historial de versiones
- documentacion de deploy, migracion o CI cuando resume evolucion historica
- reportes finales que declaran version, alcance o estado de release

## Read-set Obligatorio

Antes de proponer escritura, el leader o `auditor(profile: release)` debe leer lo disponible y declarar que falta:

- `CHANGELOG.md`
- `PROGRESS.md`
- `orquestador/sdd/progress/state.yaml`
- `orquestador/sdd/progress/registry.yaml`
- `orquestador/sdd/progress/registry.md`
- `orquestador/sdd/progress/cycles/**/gate-log.yaml`
- `orquestador/sdd/progress/cycles/**/final-report.md`
- `orquestador/sdd/progress/cycles/**/audit.jsonl`
- `git log --oneline --decorate --date=short`
- `git show --stat` de commits relevantes
- evidencia externa mencionada por el operador, como capturas, logs de CI o auditorias

Si una fuente esperada no existe, se registra como gap. Si existe y no fue leida, el changelog no puede pasar review.

## Matriz Obligatoria

Antes de escribir se debe completar una matriz usando:

- `orquestador/sdd/progress/templates/changelog-reconstruction-checklist.md`
- `orquestador/sdd/progress/templates/release-history-matrix.yaml`

La matriz debe separar:

- hecho observado
- inferencia
- evidencia
- commit/ciclo asociado
- tipo de cambio
- version propuesta o real
- seccion de changelog
- gaps o preguntas abiertas

## Reglas de Versionado

1. Ordenar versiones de mas nueva a mas vieja.
2. No usar `sin version` para eventos versionables. Si falta version historica, proponer una version sintetica y marcarla como `synthetic/proposed`.
3. No mezclar concerns distintos si ocurrieron como ciclos o releases separados. Ejemplo: CI, deploy, migracion y documentacion pueden requerir entradas separadas.
4. No colapsar varias iteraciones de CI/deploy en una sola linea si el objetivo es documentar como se llego al pipeline funcional.
5. No mover eventos entre versiones sin evidencia o justificacion explicita.
6. Si el operador corrige el orden/versionado, esa regla queda como hard lock de la sesion.

## Gate de Review

Toda edicion de changelog debe pasar un review especifico:

- Reviewer o `auditor(profile: release)` compara matriz vs changelog.
- Cada entrada nueva debe tener evidencia o quedar marcada como inferencia.
- Si hay evento sin version, commit sin mapear o ciclo incongruente, el gate queda `blocked`.

## Criterio de Done

No declarar `done` si:

- no se leyo `git log + PROGRESS.md + registry` cuando existen;
- no hay matriz de reconstruccion;
- el changelog no se puede rastrear a evidencia;
- el orden de versiones fue inferido sin declararlo;
- se omitieron eventos mencionados por el operador o por el registro local.
