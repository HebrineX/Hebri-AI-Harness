# Detractor Senior - C-001 / P00-T04

- Approval ID: `P00-T04-EXEC-014`
- Auditor: `A-P00-A04`
- Execution mode: simulated; no real subagent was available
- Proposed change: architecture decision evidence plus approved cycle/state tracking only

## Review

- No accepted requirement needs a continuously resident process, service account, listener or database.
- On-demand PowerShell plus optional host-launched MCP stdio reuses the current platform and keeps project context isolated by process/invocation.
- A daemon would add install, privilege, authentication, update and recovery work before a workload justifies it.
- A database would add schema, backup, migration and offline distribution work before catalog behavior or contention is measured.
- Existing Node/MCP dependencies are sufficient for the optional adapter, but the undeclared direct `zod` import and 93-entry transitive lock tree are packaging risks, not reasons for a service.
- The two new documentation files are necessary evidence. All other writes are existing tracking files; no product edit or dependency change is allowed.

## Verdict

- Verdict: accept
- Minimum architecture: per-invocation core, session-scoped stdio MCP, durable file contracts, no resident service, no database, no new dependency.
- Reconsider only with measured latency/concurrency/query evidence or a newly accepted background/remote requirement.
- Do not weaken: explicit project context, file-based authority, approvals, locks/journal, fail-fast offline dependencies and optional backend disclosure.
