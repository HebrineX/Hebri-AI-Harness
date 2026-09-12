# P02-T06 - Writer integration and explicit exceptions

The known PowerShell business writers accept `RuntimeMode` and operation-safety context. In `central_instance`, mutation requires all of the following before the first business effect:

- valid descriptor and exact operation name;
- live scoped approval;
- approval-bound, current-owner lock covering every target;
- journal bound to the same descriptor/project/approval/lock in `applying` state.

Integrated surfaces are command gateway, bootstrap, bound update, restore, migration, instruction generation, Claude reentry, Claude hook install, host integration install and both regularizers. P02-T06 dynamically proves that central bootstrap without operation context fails `APPROVAL_REQUIRED` before creating its target.

Explicit exceptions:

- `source_template` is repository authoring mode.
- `legacy_bound` preserves the old runtime during migration.
- approval issuance is a control-plane prerequisite and cannot require the approval it is creating.
- legacy Markdown lock acquire/release is rejected in `central_instance`.

Deferred integration boundaries:

- P03/P04 must derive and pass `central_instance` from the resolved binding in CLI/MCP launch paths. Until then, selecting source/legacy mode is explicit caller behavior, not automatic installed-host enforcement.
- P06 must add the new artifacts to the executable payload manifest; `orquestador/harness-manifest.txt` was intentionally not edited in P02.
- P06/P08 must enforce store ACLs, installed-product identity and clean-host validation.

No Git, network, elevation, installation, MCP edit or real consumer mutation occurred in P02.
