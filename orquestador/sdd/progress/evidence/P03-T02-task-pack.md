# P03-T02 - Strict task pack

`orquestador/runtime/schemas/agent-task-pack.schema.json` and its template define a closed `agent-task-pack/1` contract. It binds task/project/actor/role, explicit execution mode, objective, requirements, invariants, operations, read/write scopes, context references, budget, approval metadata, tests, stop conditions and expected output.

The runtime performs semantic enforcement without adding a dependency: unknown fields and wrong array/boolean/integer types block; paths must be relative and contained; existing reparse points block; required context must exist and match SHA-256; role and requested capabilities must intersect; write/network/process/elevation declarations must agree with scopes and operations; known context-window arithmetic and declared input limits are enforced.

`P03-V02` rejects missing invariants, missing required inputs, over-budget input, the 80-percent repack threshold, unknown fields and wrong types. These failures produce structured read-only decisions and do not create the expected output path.

Evidence: `orquestador/runtime/schemas/agent-task-pack.schema.json`, `orquestador/runtime/templates/agent-task-pack.template.json`, `scripts/agent-runtime.ps1`, `scripts/validate-agent-context.ps1`.
