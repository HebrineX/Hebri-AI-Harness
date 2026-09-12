# P02-T03 - Canonical operation journal

Contract: `hebrinex.operation_journal` version `1.0.0`, runtime API `1`.

Allowed durable transitions:

| From | To |
|---|---|
| `prepared` | `applying`, `rolling_back`, `recovery_required` |
| `applying` | `committed`, `rolling_back`, `recovery_required` |
| `recovery_required` | `rolling_back`, `applying` |
| `rolling_back` | `rolled_back`, `recovery_required` |
| `committed` | terminal |
| `rolled_back` | terminal |

Each transition appends a timestamped, redacted and bounded evidence entry. The journal binds operation, project, descriptor, approval and lock, and records resource pre-hash, backup path, published hash and last confirmed stage.

Approval is not a journal state. Authorization is validated separately before lock acquisition and mutation. A process interruption leaves a non-terminal durable journal; status derives `recovery_required` when its owner is no longer verifiably live.

The schema and template are in `orquestador/runtime/schemas/operation-journal.schema.json` and `orquestador/runtime/templates/operation-journal.template.json`.
