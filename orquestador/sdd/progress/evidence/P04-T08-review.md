# P04-T08 - Reviewer report

Role: reviewer, simulated explicitly in the visible process; read-only during
the review pass. The public CLI roundtrip itself ran in child PowerShell
processes. No external AI reviewer/backend was claimed.

Verdict: `pass_with_release_limits`.

## Findings resolved before verdict

1. MCP initially added top-level metadata to a closed CLI result. Moved that
   metadata under `details.mcp` so the result schema remains valid.
2. Project/catalog roots could overlap the trusted product. Added fail-closed
   root separation and reparse-point checks before approve and Apply.
3. A handcrafted P02 descriptor could use an unsupported action or mixed
   identities. Added a closed project-plan grammar, exact write-set validation
   and cross-document identity/root/state checks before approval and execution.
4. Reconcile did not include the authoritative binding in its approved
   preconditions when only catalog repair was planned. It now rewrites and
   preconditions the binding in every reconciliation.
5. Rollback could overwrite a concurrent external edit. It now restores only
   resources whose current hash still equals the content written by P04; any
   divergence is preserved and becomes `RECOVERY_REQUIRED`.
6. Long inline descriptor JSON is not portable through Windows PowerShell 5.1
   native argument quoting. The documented portable path uses
   `-OperationDescriptorPath`; JSON-in-memory remains valid on PowerShell 7/MCP.

No reviewer finding remains open in P04 source scope.

## Residual limits

- Installed payload/manifest, launcher trust and MSI ownership belong to P06.
- Legacy conversion belongs to P05; upgrade/repair lifecycle belongs to P07.
- Clean/offline VM, installed ACLs, real symlink capability and release-grade
  independent external review belong to P08/P09.
- `gate_check` was intentionally omitted from the MCP smoke via `-NoGit` because
  this approval excluded Git. All other MCP smoke paths ran.
