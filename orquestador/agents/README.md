# Agents — Autoridad, Contratos e Identidad de Rol

Este directorio gobierna los roles del harness. La fuente narrativa de cada rol es
`agents/<rol>.md` (raiz del repo); los derivados (`role-contracts/*.yaml`,
`prompts/roles/*.prompt.md` y el bloque `role_defaults` de `capability-registry.yaml`)
se regeneran con `scripts/build-instructions.ps1 -WriteOutputs` y NO se editan a mano.

- `agent-registry.yaml`: roles validos y autoridad (`harness_only`; la IA no define roles).
- `capability-registry.yaml`: capabilities y sus requisitos (preflight, SI, lock, scope).
- `lifecycle-registry.yaml`: estados y transiciones validas de agentes.
- `scripts/agent-runtime.ps1`: enforcement ejecutable rol+capability (+transicion).

## Identidad de rol: garantia real y limite residual (sin teatro)

Hay dos vias de enforcement de rol y NO dan la misma garantia:

1. **Via MCP (garantia fuerte).** El daemon (`mcp/server.mjs`) mantiene el rol de la
   sesion en el estado de su proceso: se asume una sola vez con la tool `role_assume`
   (validada contra `agent-registry.yaml`) y las tools con efecto (`run_command`,
   `lock_acquire`, `lock_release`) consultan `scripts/agent-runtime.ps1` con ESE rol.
   El caller no puede declarar un rol distinto por llamada: si el rol asumido no tiene
   la capability, la tool falla con `role_capability_blocked`.

2. **Via CLI directa (autodeclarada).** `hebrinex agent-runtime -RoleId <rol> ...` y
   `hebrinex lock -Acquire -Owner <id>` aceptan el rol/owner que el caller declare.
   El enforcement de capabilities se evalua correctamente para ese rol, pero nada
   impide que un caller local declare otro rol: es enforcement de contrato, no de
   identidad.

Limite residual documentado: mientras el CLI directo exista (y debe existir: es la
base auditable que el daemon envuelve), la garantia de identidad fuerte existe SOLO
para sesiones que operan via MCP. Un proceso local con acceso al filesystem puede
saltarse ambas vias; el harness defiende flujo y evidencia, no reemplaza permisos
del sistema operativo.

Sin `role_assume` previo, las tools MCP con efecto funcionan sin check de rol
(compatibilidad con 0.13/0.14); el resultado expone `role_enforced=false` para que
la falta de identidad quede visible en la evidencia, no escondida.
