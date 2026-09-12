# P03-T05 - Verifiable result and cold handoff

An agent result must reference the exact task pack by path and SHA-256 and repeat its task, project, actor, role and execution mode. Allowed result capabilities must be enforced by the role and present in the task pack. A claimed write requires both an enforced write capability and a non-empty task write-set. Provider text always remains non-authoritative.

A handoff binds project/task/mode to a hashed result, hashed source evidence, hashed approvals and hashed journals. Cold validation reparses the linked result/task pack and checks approval contract/ID/project/status/expiry, journal contract/project/operation identity/state, stale hashes and committed-effect replay. It blocks recovery-required or applying journals instead of repeating an effect.

`P03-V03` accepts a complete cold handoff without chat history and rejects stale evidence, expired approval, mismatched journal identity and a committed effect. The validator uses synthetic, marker-owned files only and removes the verified temporary directory.

Evidence: `orquestador/runtime/schemas/agent-result-v1.schema.json`, `orquestador/runtime/schemas/agent-handoff.schema.json`, matching templates, `scripts/agent-runtime.ps1`, `scripts/validate-agent-context.ps1`.
