# P03-T01 - Role and capability enforcement

Approval: `P03-LOCAL-022`; legacy envelope `APR-20260909T183629Z-47534e`.

The pre-existing runtime decided one role/capability pair. `scripts/agent-runtime.ps1` now preserves that interface and adds task-pack actions whose effective permission is the intersection of:

1. the generated role defaults and role contract;
2. the operations and scopes declared by the task pack;
3. the selected provider tuple and its host, adapter and model enforcement states.

Explicit deny wins. Unknown roles/capabilities, write operations without a write-set and approval, network/elevation/process flags without matching capabilities, and capabilities without matching flags block. Reviewer and auditor write attempts remain denied by the original role contracts.

Security registries now record that provider output cannot define permissions and that effective capability is an intersection. The legacy `Capability` action and state-transition behavior remain compatible; `validate-agent-runtime.ps1` passes in PowerShell 7 and 5.1.

Evidence: `scripts/agent-runtime.ps1`, `orquestador/agents/capability-registry.yaml`, `orquestador/security/permission-registry.yaml`, `scripts/validate-agent-context.ps1` (`P03-V01`).
