# Harness Runtime Commands

Los comandos son una interfaz de lectura/rehidratacion. No saltan preflight.

| Comando | Lectura esperada | Efecto | Regla |
|---|---|---|---|
| `/harness status` | binding, session pin, budget, active-session | ninguno | no cargar contexto completo |
| `/harness reentry` | status + state/registry si entra en budget | expira approvals | pedir `SI` para efectos |
| `/harness manual` | operating modes | cambio persistente solo con `SI` | no relaja seguridad |
| `/harness automatico` | operating modes | cambio persistente solo con `SI` | no relaja seguridad |
| `/harness audit` | preflight de auditoria | ninguno por defecto | no hacer auditoria global automatica |
| `/harness budget` | budget + read-set declarado | ninguno | bloquear sobrepresupuesto |

Salida obligatoria: estado, read-set, over-budget, bloqueos y siguiente paso.
