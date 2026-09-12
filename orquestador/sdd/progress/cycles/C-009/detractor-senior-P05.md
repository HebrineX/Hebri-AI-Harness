# P05 detractor senior

Cycle: `C-009`
Role: simulated auditor, profile `detractor_senior`
Verdict: `pass_with_conditions`

## Findings before implementation

1. `scripts/migrate-harness.ps1` is a product-version migration utility, not a
   safe full-copy-to-central-instance migrator. Its backup lives below the
   traversed tree and records size/time instead of content hashes.
2. Existing bound update/restore behavior is useful legacy compatibility, but
   broad overwrite semantics cannot decide legacy drift for P05.
3. P02 already owns approval, lock, immutable descriptor and journal. P04 owns
   binding, catalog and lightweight instance publication. A second transaction
   format or catalog is rejected.
4. No external dependency is justified. PowerShell/.NET hashing, JSON and
   filesystem APIs are sufficient.
5. A version is supported only when a baseline descriptor and fixture are
   content-addressed and exercised. Missing local history means `unsupported`,
   never inferred compatibility.

## Non-negotiable conditions

- Plan is read-only and enumerates exact reads, writes, snapshot and space.
- Apply reparses and rehashes the immutable plan before any mutation.
- Snapshot is outside the legacy tree, excludes prior snapshots/staging and has
  a SHA-256 manifest verified before publication or restore.
- Conflicting shared bytes require an explicit decision recorded in the plan.
- Unknown and personal instance files are preserved without printing content.
- Restore refuses corrupt snapshots and refuses to overwrite post-migration
  changes without a new plan.
- Locks remain outside the directory being replaced; catalog runs after local
  commit and failure is reported as recovery required.
- Tests use disposable fixtures only. No real consumer, backup deletion,
  `.gitignore`, manifest/payload, network, elevation or installer work.

These conditions bound P05-T01..T08 and must be rechecked by the reviewer.
