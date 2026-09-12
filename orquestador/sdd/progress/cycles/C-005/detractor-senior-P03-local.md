# Detractor senior - P03 local foundation

Agent: `A-P03-A01`, simulated auditor role. It does not implement or approve.

Verdict: `pass_with_conditions`.

## Necessity

P03 needs a machine-readable task package and verifiable handoff because the existing role runtime checks one declared capability at a time and does not bind scope, evidence hashes, budget, host limitations or cold reentry. Extending that runtime is justified; a new orchestrator, daemon, database, vector store or model router is not.

## Required constraints

1. Use closed JSON contracts and platform/stdlib parsing. Do not add a YAML or schema dependency for the core runtime.
2. Reuse P01 resolved-root and P02 approval/operation concepts by reference; do not create alternate path, approval or lock authorities.
3. A role declaration cannot grant capability. Effective permission is the intersection of role, task pack, host and adapter; missing data blocks.
4. Distinguish `enforced`, `advisory`, `unsupported` and `not_tested`. Prompts and documentation are never reported as runtime enforcement.
5. Context loading must verify declared hashes, enforce path scope and label external/provider output as untrusted data.
6. Budget arithmetic must preserve host reserve, output reserve and safety margin. Unknown host telemetry stays unknown; no invented token use.
7. Result and handoff validation must detect stale evidence, consumed/expired approval and already committed operations before reentry.
8. Provider commands remain fixed configuration with prompt on stdin. Provider output is parsed as data and cannot change role, approval or scope.
9. Freeze corpus, repetitions, candidates and thresholds before any live call. Offline fixtures cannot prove model quality or provider equivalence.
10. Keep `mcp/server.mjs`, payload manifest, Git, network, installation, elevation, secrets and real consumers outside this approval.

## Non-negotiable stop

Stop if implementation requires a new dependency, provider invocation, broader MCP service change, unbounded prompt/history load, fabricated usage, or a write outside the declared set.
