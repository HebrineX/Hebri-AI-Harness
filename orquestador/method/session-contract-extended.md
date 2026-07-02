# Contrato de Sesion Extendido

Version: 0.11.0

Este documento conserva la operacion completa del harness. No se carga por defecto. Usarlo cuando el kernel no alcanza: auditoria global, migracion, drift complejo, cierre de fase, reconstruccion historica o conflicto de reglas.

## Modos

- `automatico`: el leader decide pasos seguros dentro del scope, pero pide `SI` antes de editar, ejecutar comandos, usar red/git, llamar APIs/modelos, instalar, cambiar estado SDD o abrir trabajo con riesgo.
- `manual`: el operador aprueba cada paso o slice antes de ejecutarlo.

## Handoff

Antes de pasar de un rol a otro:

```text
Handoff:
- De: [rol/agente]
- A: [rol/agente/humano]
- Estado: [done | blocked | cancelled]
- Evidencia: [archivos/comandos]
- Pendiente: [lista]
- Riesgo: bajo | medio | alto
- Requiere SI para continuar: si | no
```

## Re-entry Post-Compactacion

Si la sesion fue compactada, resumida, retomada desde logs o cambia cwd/proyecto:

1. Validar `PROJECT_BINDING.yaml`.
2. Confirmar `binding_mode` y `project_root`.
3. Declarar contrato de sesion completo.
4. Cargar `reentry_light` salvo auditoria/migracion compleja.
5. Expirar approvals pendientes salvo revalidacion explicita.
6. Confirmar ciclo activo, locks, agentes abiertos y handoffs.
7. No escribir hasta reconstruir estado.

## Correccion de Desvios

Si el operador detecta desvio:

1. Parar ejecucion nueva.
2. Repetir la regla corregida.
3. Marcarla como hard lock de sesion.
4. Reconstruir roles, locks, registry, handoffs y siguiente accion.
5. Pedir `SI` antes de retomar si hubo o habra efectos.

## Artefactos Derivados

Para changelog, release notes, roadmap, deploy docs o reportes historicos:

1. Leer `evidence-reconstruction.md`.
2. Si toca versiones, leer `changelog-policy.md`.
3. Reconstruir hechos desde `git log`, `PROGRESS.md`, registry y ciclos.
4. Separar hechos, inferencias, contradicciones y gaps.
5. Completar matriz/checklist aplicable.
6. Pedir `SI` para escribir.

## Controles Condicionales

| Caso | Control |
|---|---|
| deploy/migracion | `deploy-migration-policy.md` |
| drift version/referencias | `reference-drift-policy.md` |
| CI/pipeline iterativo | `ci-pipeline-policy.md` |
| P0/P1/P2 | `backlog-policy.md` |
| auditor/reporter | `audit-reporting-policy.md` |
| cierre fase/ciclo | `final-report-evidence-policy.md` |
| presets IA | `ai-preset-policy.md` |
| memoria/adapters | `memory-layer-policy.md`, `adapter-contract.md`, `context-loading-policy.md` |

## Cierre de Ciclo

No declarar `done` sin:

- consolidacion explicita del leader;
- `state.yaml` y `registry.yaml` coherentes;
- locks resueltos o bloqueados;
- gate log con resultado binario;
- evidencia y verification matrix si aplica;
- final report si aplica;
- agent closure para todos los agentes;
- handoff escrito si pasa a otro rol;
- gaps nuevos registrados;
- validacion ejecutada o bloqueo documentado.