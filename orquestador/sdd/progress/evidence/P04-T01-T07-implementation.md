# P04-T01..T07 - Implementation evidence

Approval: `P04-COMPLETE-025`; session envelope `APR-20260910T042944Z-46d7e3`.

Execution mode: explicit simulated leader/auditor/executor roles. No real subagent
or provider execution was claimed.

## Delivered

- T01: additive CLI `scripts/hebrinex-central.ps1`, API `central1`; legacy
  `scripts/hebrinex.ps1` remains the `stable0.5` oracle and its SHA-256 is
  `6feb422dfa1cd38e18410e21d1893b484b6d2bf921be0f91ea9a0e2837317281`.
- T02: closed JSON contracts for binding, instance seed, registration, catalog
  and CLI result. Binding identity is authoritative and cannot select code.
- T03: plan -> human SI -> APR2 -> same-process lock/journal -> staging ->
  precondition recheck -> commit. The seed contains project data only.
- T04: one recoverable catalog file per project. Catalog failure after local
  commit returns `REGISTRATION_PENDING`, exit 8 and preserves the binding.
- T05: `status`, `list`, `doctor` and `validate` are pure reads; fixture tree
  fingerprints remain identical before and after queries.
- T06: explicit-root reconciliation distinguishes missing registration, move
  and simultaneous duplicate. Copy-as-new changes both project and instance ID.
- T07: conservative unbind archives identity and preserves instance data.
  Claude hooks run central scripts from trusted `InstallRoot` and resolve state
  from the project instance.

## Main artifact hashes

- `scripts/lib/project-service.psm1`:
  `2a8fce668e9d169f33137668e5c8ed29bb01bc0c870d355e2fe4b7ad6f815cd9`
- `scripts/hebrinex-central.ps1`:
  `6f5a55e13aa3edef2494636d70d29102627144d84980807d840c42470990de4a`
- `scripts/validate-project-service.ps1`:
  `31a49138aec20afe8135f6c412b575194107c9c6605db6a849995e8ed6d868f6`
- `mcp/server.mjs`:
  `85d7cffda4dbbf2f2b4d5a6231efeaa32ed617789587d699e1d2a3ff50c2b6db`

Hashes identify the reviewed pre-closure product state; tracking-only files are
written afterward and do not alter these four artifacts.

## Excluded effects

No Git, network, provider, dependency installation, elevation, MSI, real user
catalog or real consumer project was used. Temporary fixture residue after every
completed validator run: zero.
