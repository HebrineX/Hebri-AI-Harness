# P03-T04 - Provider capability separation

`orquestador/agents/provider-capability-matrix.json` separates provider ID, host, adapter and model. Each dimension and the effective tuple use only `enforced`, `advisory`, `unsupported` or `not_tested`; selection requires `enforced` for every requested operation in all dimensions.

The deterministic offline fixture is `available` only for local read-only conformance and uses `execution_mode=simulated_roles`. `claude-cli` and `codex-cli` remain `not_tested`; configured commands or installed binaries are not accepted as enforcement evidence. Provider selection is read-only and never invokes a CLI. If the selected provider needs network, the decision reports `provider_execution_approval_required=true`; selection itself does not authorize that external effect.

`mcp/agent-backends.mjs` now normalizes every backend result as `untrusted_provider_output` with `instruction_authority=false`, including unavailable, unknown, malformed and hostile output. Node built-in tests pass without invoking providers. Integration of these contracts into `mcp/server.mjs` remains P04-owned.

Evidence: `orquestador/agents/provider-capability-matrix.json`, `orquestador/runtime/schemas/provider-capability-matrix.schema.json`, `mcp/agent-backends.mjs`, `mcp/agent-backends.test.mjs`, `scripts/validate-agent-context.ps1` (`P03-V05/V06`).
