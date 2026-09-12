# Detractor Senior - C-004 / P02-T01-T08

- Operator approval: `P02-COMPLETE-021`
- Runtime envelope: `APR-20260909T150307Z-6dd2d0`
- Auditor: `A-P02-A01`
- Execution mode: simulated; no real subagent was available
- Scope: implement and close P02 state safety without external or real-consumer effects

## Challenge

- Reuse `scripts/lib/hebri-common.psm1`; no daemon, database, broker, new dependency or per-writer framework is justified.
- Preserve legacy approval, lock and CLI result interfaces. New operation safety is a separate versioned contract; the broad P02 approval is phase evidence, not a reusable scoped-operation approval.
- Canonical descriptors must deterministically bind project identity, operation, roots, write-set, plan, code version and preconditions.
- Atomic overlap exclusion requires a per-instance acquisition guard plus atomic lock-file creation. A hash per resource alone cannot serialize ancestor/descendant scopes.
- Lock owner identity includes PID, process start UTC and host identity. Expiry alone never authorizes stealing a verified live lock; unverifiable ownership returns `LOCK_OWNER_UNVERIFIED`.
- Approval is a precondition, never a journal state. Journal states are limited to `prepared`, `applying`, `committed`, `rolling_back`, `rolled_back` and `recovery_required`.
- Safe publication promises atomicity only for one file on one volume. Multi-file and cross-volume work uses journaled compensation and never claims global atomicity.
- Every central-runtime business writer must use the operation contract or fail closed. Source-authoring and fixture-only utilities must be explicitly classified rather than silently treated as runtime bypasses.
- `status`, validation and `CheckOnly` paths must not create directories, rate files, access timestamps or caches.
- Failure injection is restricted to marked fixtures and identifiable child PowerShell processes. No real consumer, external, elevated, network or Git effect is allowed.
- V01-V07 must execute against real exported functions. A skipped security oracle blocks phase closure.

## Verdict

- Verdict: proceed with conditions.
- Required implementation: one shared stdlib-only operation API, versioned schemas, central writer guards, real-process tests, evidence and closed tracking.
- Required rollback: restore only C-004-owned source changes; preserve failure journals as evidence until review; never overwrite later operator changes.
- Required closure: reviewer finds no open safety finding, aggregate validation passes, cycle lock is released and no agents or operations remain open.
