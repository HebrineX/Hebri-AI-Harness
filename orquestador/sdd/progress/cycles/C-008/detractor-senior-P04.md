# C-008 detractor senior - P04

Role: simulated `auditor(profile: detractor_senior)`; no independent process is claimed.

Verdict: `pass_with_conditions`.

## Minimum justified design

- Preserve `scripts/hebrinex.ps1` and its public `stable0.5` grammar unchanged.
- Add one explicit `central1` CLI/service and closed JSON contracts for binding, seed, registration, catalog and result.
- Reuse P01 root resolution and P02 descriptor, scoped approval, lock and journal APIs; do not create a second authorization system.
- Keep catalog entries as reconstructible observations. Binding remains project authority.
- Add one MCP translation tool with explicit roots per call; do not retain project context in daemon-global state.

## Non-negotiable limits

- Init creates only binding plus minimal instance data and catalog entry; it never copies the product payload.
- Check-only status, list and doctor perform zero writes, including cache and last-access updates.
- Project effects are tested only in marker-owned temporary fixtures. No real consumer, user catalog, Git, network, installer or elevation effect.
- Reconciliation scans only explicit approved roots and blocks simultaneous duplicate identities.
- Unbind archives the binding and marks the catalog entry unbound; it preserves instance data.
- Hooks may resolve the central service but are not installed in this cycle.
- P03-V04 remains deferred to P08 and is not converted into PASS.

The auditor permits implementation inside the declared P04 write-set. Any need to publish the executable manifest or build an installer stops for P06.
