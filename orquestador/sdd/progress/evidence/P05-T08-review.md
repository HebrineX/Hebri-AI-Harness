# P05-T08 - Reviewer report

Role: reviewer, simulated explicitly and read-only during review passes. No
independent process or external AI reviewer was claimed.

Verdict: `pass_with_pilot_and_release_limits`.

## Findings resolved before verdict

1. The legacy validator initially required P05 files inside older minimal bound
   fixtures. P05 checks are now conditional when that service is present; the
   aggregate still validates the complete source tree.
2. The first descriptor check accepted loosely shaped nested plans. It now uses
   closed properties, exact operation paths/write-set, file dispositions,
   identities, document contracts, stages, rollback and fixture-only failures.
3. Space detection failed open if the volume could not be queried. It now blocks
   as `INSUFFICIENT_SPACE`; test-only overrides are rejected outside marked fixtures.
4. Existing bound restore verified entries while it could already be copying.
   It now verifies the entire manifest before the pre-restore backup or first
   target write, then rechecks source and destination SHA-256.
5. The initial P05 snapshot retained historical backup trees. They are now moved
   losslessly to a sibling area with a separate manifest, excluded from restore
   snapshots, restored during pre-publication rollback and proven nonrecursive.
6. Failure coverage lacked the post-publication branch. The matrix now proves
   it returns `MIGRATION_RECOVERY_REQUIRED`, preserves snapshot and instance,
   and never reports success.
7. Privacy/reparse behavior was implicit. A private `.env` fixture is preserved
   by hash without appearing in plan output, and a real junction is rejected
   without reading or changing its external witness.

No reviewer finding remains open in P05 source scope.

## Residual limits

- Full-tree tag runs passed locally for `v0.10.11` and `v0.16.0` only. Every
  unlisted version remains unsupported.
- P06 owns packaged baselines, payload/manifest inclusion and installed launcher.
- A disposable-copy pilot and any real consumer require a new project-specific SI.
- Clean/offline VM, installed ACLs, forced process termination at P05-specific
  durable stages and independent external review remain P08/P09 gates.
- Git emitted a permission warning for the user global excludes file; local
  `git archive` still completed and both baseline hashes were verified.
