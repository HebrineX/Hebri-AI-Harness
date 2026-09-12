# P03 local foundation - Final handoff

Approval: `P03-LOCAL-022`; legacy runtime envelope `APR-20260909T183629Z-47534e`.

Verdict: `accepted_local_foundation_with_provider_and_packaging_blockers`.

## Delivered

- Backward-compatible agent runtime actions for strict task-pack validation, selective context loading, provider selection, result validation and cold handoff validation.
- Closed JSON schemas/templates for task packs, context reports, results, handoffs and provider capabilities.
- Role/task/host/adapter/model capability intersection with fail-closed states.
- SHA-256 provenance across task pack, result, handoff, source, approval and journal references.
- Budget arithmetic and the 80-percent repack gate without invented host telemetry.
- Untrusted provider-output normalization plus offline malformed/hostile/unavailable tests.
- Sanitized corpus and fixed experiment thresholds frozen before any provider call.
- Instance layout mappings for future task packs, context reports, results, handoffs and evaluation results.

## Verification matrix

| Oracle | PowerShell 7.6.5 | Windows PowerShell 5.1.26100.9444 |
|---|---|---|
| P03-V01 read task then denied write | PASS | PASS |
| P03-V02 missing input/invariant, strict types, budget and 80-percent gate | PASS | PASS |
| P03-V03 cold handoff, stale/expired/mismatch/replay rejection | PASS | PASS |
| P03-V04 live provider baseline/candidate evaluation | NOT RUN; frozen | NOT RUN; frozen |
| P03-V05 unavailable/malformed/hostile provider boundaries | PASS | PASS |
| P03-V06 explicit simulated-role limits | PASS | PASS |
| Node backend tests | PASS (4/4) | PASS through P03 validator |
| Full `validate-harness.ps1 -RunNegativeTests` | PASS | PASS |

Inherited aggregate warnings remain below hard context limits. P01's real-symlink creation oracle remains host-blocked; P03 adds a conservative reparse-point denial but does not claim the privileged symlink test passed. Temporary P03 residue: none.

## Project impact

Before this slice, the runtime checked one role capability but did not bind a complete task, context provenance, provider enforcement evidence or a cold handoff. After it, local dispatch contracts can fail closed before a provider receives work and can reconstruct the result chain without chat memory. No provider was called and no autonomous multi-process agent system was introduced.

Compatibility is additive: the original `agent-runtime.ps1 -RoleId ... -Capability ...` path still passes. MCP server dispatch is intentionally unchanged until P04.

## Open blockers

- `P03-B01`: T07, normative V04 and T08 require a separate network/data/cost approval and real provider executions.
- `P03-B02`: P04 must integrate task-pack/result/handoff enforcement into `mcp/server.mjs` and carry verified project/instance context.
- `P03-B03`: P06 must add the P03 schemas/templates/matrix/corpus/validator/tests to the executable manifest and registries atomically; this slice did not edit `orquestador/harness-manifest.txt`.
- Release independence remains unproven because the reviewer was an explicit simulated role in the same process.

## Rollback

Remove the additive P03 runtime actions, schemas/templates, provider matrix, evaluation corpus/plan, agent-context fixtures/validator, MCP backend normalization/tests, layout mappings, security deltas and P03 tracking. Preserve pre-existing P01/P02 contracts. No external rollback is required because this slice used no network, Git, provider, installation, elevation or real consumer.

## Next action

Prepare exact preflight `P03-PROVIDER-EVAL-023` from the frozen experiment plan. It must name provider commands, sanitized read-set, network destinations, data boundary, call count, cost limit, result write-set and stop conditions. Do not infer that approval from `P03-LOCAL-022`.
