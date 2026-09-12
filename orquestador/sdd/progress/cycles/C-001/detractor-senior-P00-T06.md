# Detractor Senior - C-001 / P00-T06

- Approval ID: `P00-T06-EXEC-016`
- Auditor: `A-P00-A07`
- Execution mode: simulated; no real subagent was available
- Proposed change: one fixture-design evidence file, this review and approved tracking only

## Challenge

- Creating fixture trees before the canonical binding/state schemas and real resolver exist would turn examples into accidental contracts.
- Six scenario groups are sufficient for P00. Additional files or a generator framework would be premature unless implementation shows unavoidable duplication.
- Existing regex fixture checks prove marker presence, not parser rejection or zero writes. T06 must not reuse their PASS as central-binding runtime evidence.
- A fixture described as `legacy intact` cannot be called valid while the observed binding says `0.17.1` and its schema requires `0.17.0`.
- A corrupt-state oracle is ambiguous while the reference state schema itself contains literal `` `n `` defects.
- Conflict, duplicate identity and moved-root cases need distinct preimages. Renaming one contradictory tree three times would not satisfy P00-V02.
- Random GUIDs, timestamps or ambient temp paths would make expected output unstable. Fixed fixture IDs and explicit path tokens are required.
- A duplicate-copy test must snapshot both projects; checking only the selected root would miss cross-project writes.
- Synthetic fixtures must not contain real approvals/evidence or even text that could be mistaken for operator authorization.

## Verdict

- Verdict: accept design with blocking contract defects.
- Accept: six explicit scenario groups, three independent contradictions, deterministic synthetic identities, per-scenario manifests, real-implementation oracles, pre/post hashes and verified temp-root cleanup.
- Reject: fixture instantiation in P00-T06, regex-only acceptance, copied real state, shared mutable inheritance, silent fixture regeneration and any claim that the designed cases passed.
- Required before implementation: canonical `hebrinex.binding@1`, legacy version-contract decision, repaired state schema, versioned result semantics and an approved temporary-tree write/cleanup preflight.
- Non-negotiable: zero real secrets/personal data, zero cross-project effects and zero writes on inspect/CheckOnly/conflict/corruption paths.
