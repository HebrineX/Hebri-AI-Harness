# Gateway and bounded discovery

## Approval is not capability

A blocked command never becomes executable merely because requires_si is false.
Check decision first. Syntax, policy, root containment and rate limits are not
overridden by SI. Only an authorization failure requests a corrected approval.
Do not respond to a capability rejection by executing the same command directly
or repeatedly requesting SI.

Supported Raw reads include both exact forms:

    Get-Content -Raw -LiteralPath 'scripts/command-gateway.ps1'
    Get-Content -LiteralPath 'scripts/command-gateway.ps1' -Raw

Relative paths are resolved under the gateway Root, normally .hebrinex.
Do not prepend .hebrinex again. Extra switches, duplicate Raw, shell composition
and paths outside Root remain blocked. A changed command needs its own exact
approval when the operating contract requires one.

## Separate discovery entrypoint

scripts/inventory-harness.ps1 is a dedicated Windows-local discovery workflow,
not a command accepted by command-gateway.ps1 and not a general shell executor.
Its use requires an explicit preflight approving this entrypoint and its roots.
If the current consumer contract requires every operation through the generic
Gateway, obtain explicit approval for this dedicated workflow before using it;
never silently bypass that contract.

Use only trusted reviewed source. Root selects the local authority's approval
store, not the external distribution as operational authority. Read that local
contract and confirm its project binding before proposing the workflow.

1. Present a preflight including exact absolute search roots, exclusions and
   limits. Wait for SI before invoking even CheckOnly.
2. Run inventory-harness.ps1 -Root <authority> -RootsJson <JSON array>
   -CheckOnly. This produces command_text and the complete deterministic plan,
   without scanning search roots or writing files.
3. Show that plan. The approved scope must explicitly cover it and the approval
   record write. Record its exact command_text with the authority's
   hebrinex.ps1 approve -Apply -CommandText <exact returned string>.
4. Run inventory-harness.ps1 with the SAME Root, RootsJson and limit arguments,
   -Apply and the returned -ApprovalId. Never approve explanatory prose instead
   of command_text or reuse a different command's approval.
5. Inspect JSON coverage, limit, records and exit code. 0 means discovery within
   its declared scope, 3 means partial coverage, 2 means blocked or invalid.
   Do not interpret partial coverage as global absence.

The plan binds authority, root order, depth, entry/result/time limits, exclusions
and version. Defaults: depth 8, 5000 queued/visited entries, 500 result records,
30 seconds, path length 1024 characters. Parameter changes invalidate approval.
Only fixed local Windows drives are supported; UNC, providers, whole drives,
remote/removable drives and non-Windows hosts are rejected.

The script reads directory metadata only under search roots: no file content,
Git commands, version reads, script hashes, migration, copy or installation.
It stops at .hebrinex and excludes .git, node_modules, artifacts, backups,
backup, snapshots, snapshot, staging, bin, obj, .venv and venv.
Links in roots, ancestors or descendants are not followed. Errors, exclusions
and caps produce partial coverage. Results are candidates, not verified
versions, bindings or complete migration classifications.

Follow-up inspection/update needs a separate scoped plan. Central instances,
shared caches and links must not be treated as independent copies.
Checks are path-based, not a defense against hostile concurrent filesystem
replacement. Run on quiescent trusted local directories. The time cap is
cooperative between filesystem calls, not an OS-level I/O cancellation bound.
Approval reuse until expiry follows the existing envelope contract; this
read-only workflow does not consume or modify approval records.

## Validation

Run scripts/validate-harness-inventory.ps1 on Windows with junction capability.
It creates only owned temporary fixtures and removes them after validation.
The generic gateway validator covers both parameter orders and non-authorizable
rejections. Neither validator authorizes running discovery on real projects.
