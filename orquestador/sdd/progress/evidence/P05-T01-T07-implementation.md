# P05-T01..T07 - Implementation evidence

Approval: `P05-COMPLETE-026`; session envelope
`APR-20260910T131504Z-b0d8e8`.

Execution mode: explicit simulated leader/auditor/executor roles. No real
subagent or external provider execution was claimed.

## Delivered

- T01: content-addressed baseline and closed classification for intact,
  modified, local, unknown, generated, conflict and personal resources.
- T02: read-only immutable plan with exact roots/write-set, SHA-256 inventory,
  space budget, preconditions, stages, rollback and APR2 requirement.
- T03: modified product blocks until one exact `preserve` decision is recorded;
  no generic legacy-wins rule exists.
- T04: the complete source is first verified after relocation. Prior backup
  trees are then preserved under sibling `prior-backups/`, with a separate
  SHA-256 manifest, and excluded from the restorable snapshot.
- T05: staging emits only central binding/instance records and preserved local
  data. Intact product is not duplicated; personal/generated data is snapshot
  only and private paths are tokenized in plan output.
- T06: P02 APR2, lock and journal wrap publication. Catalog writes happen after
  local publication; catalog failure remains `REGISTRATION_PENDING`.
- T07: restore verifies every snapshot byte, blocks later changes by default,
  and preserves the divergent central tree when that behavior is explicitly
  included in a newly approved plan.
- Existing `stable0.5` bound backups now record SHA-256. Restore validates the
  complete manifest before its first write and verifies each copied destination.

## Artifact hashes

- `scripts/lib/legacy-migration-service.psm1`:
  `84dcdfb45bc7d5befcb39caefc4ab596f093f1f6998f08fc9bd640d6358f6c7c`
- `scripts/hebrinex-central.ps1`:
  `0b70f603a00f35e1223b433de105b209072b1c4f832d725ababb31eefcbbd70c`
- `scripts/hebrinex.ps1`:
  `9ffa108a5a81686edf523063b6f05df19fa81ff6f0c89115de08d722f9f2de44`
- `scripts/validate-legacy-migration.ps1`:
  `482f243f40d8da82888e11c57b69e7924716eaad8623ed5ab0dc501e9aaa5d59`
- `mcp/server.mjs`:
  `c27780da2e5a0d4674566b835ad77ed6f4f78237efa85840a51b3a6b8a425d42`
- `orquestador/runtime/schemas/legacy-migration-plan.schema.json`:
  `3042d8bada533dd128a5bddb19ac7c2650a404217da1094815bf19757e74b93f`

Hashes identify the reviewed product state before tracking-only closure writes.

## Excluded effects

No network, Git write/commit/push/checkout, provider call, dependency install,
elevation, MSI, real user catalog, real consumer migration, backup deletion,
`.gitignore` edit or P06 payload/manifest change occurred. Completed validators
removed only their own verified temporary fixture roots.
