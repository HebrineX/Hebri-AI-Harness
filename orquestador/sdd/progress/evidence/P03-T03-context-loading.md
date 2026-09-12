# P03-T03 - Selective context and provenance

The `LoadContext` action reads only `context.references` whose paths are also in the task read-set. Every source carries path, reason, declared trust, required status, SHA-256, character count, token estimate and an explicit `instruction_authority` value.

`external_data` and `provider_output` remain non-authoritative. Cache authority is fixed to false. File bytes are read as one snapshot, hashed again during load and used for the measured character/token estimate. The runtime uses the greater of declared and measured input estimates, blocks above the task limit, and blocks for repacking at or above 80 percent. A missing host context window remains `unknown`; it is not converted to zero or an invented capacity.

The action emits a report but never persists context or creates result files. `P03-V01/V02` verify provenance, unchanged witnesses and budget behavior in PS7 and PS5.1.

Evidence: `orquestador/runtime/schemas/context-load-report.schema.json`, `orquestador/runtime/templates/context-load-report.template.json`, `scripts/agent-runtime.ps1`, `scripts/validate-agent-context.ps1`.
