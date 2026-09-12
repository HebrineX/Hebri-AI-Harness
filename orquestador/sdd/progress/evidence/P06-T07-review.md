# P06-T07 - Reviewer report

Role: `A-P06-R01`, simulated reviewer. Review passes did not edit; findings
were returned to the simulated implementer and the complete matrix was rerun.

Verdict: `pass_local_candidate_with_installation_gate_blocked`.

## Findings resolved

1. The initial .NET Framework compiler did not support deterministic output.
   Roslyn was pinned while .NET Framework 4.8 remained the target runtime.
2. Random staging filenames changed the launcher assembly identity. A stable
   staged filename now makes isolated payload inventories identical.
3. Inherited process streams hid stdout. Explicit stream forwarding preserves
   stdout, stderr and the child exit code.
4. Windows PowerShell 5.1 degraded Unicode and did not reinterpret named
   parameters from array splatting. The launcher now transfers Base64 values,
   resolves only trusted script parameter metadata and reserves InstallRoot.
5. `Path`/`PATH` duplication on the host made environment-dictionary mutation
   unsafe. The launcher no longer touches that dictionary.
6. A tampered script is rejected with exit 12 before dispatch, and fake
   `powershell.exe`/DLL files in CWD are ignored.
7. WiX validation initially failed only inside the sandbox because Windows
   Installer service access was unavailable. The identical non-elevated build
   passed ICE outside the sandbox; no install ran.
8. PowerShell 5.1 treated successful Node stderr as a terminating native error.
   MCP validation now captures streams separately and judges the process by its
   real exit code.

## Matrix

| Case | Result | Evidence |
|---|---|---|
| P06-V01 clean/offline VM install | BLOCKED | Installation and VM were excluded by approval. |
| P06-V02 new standard-user console/ACL | BLOCKED | Requires actual install and user session. |
| P06-V03 arguments/Unicode/metacharacters | PASS | Exact binding path and exit code 3 preserved. |
| P06-V04 hostile CWD and tamper | PASS | Trusted engine path; tamper rejected before CLI. |
| P06-V05 two isolated builds | PASS | 447-entry payload inventories and tree hashes equal. |
| P06-V06 MCP optional feature | PARTIAL | Core PASS; absent MCP fails closed; present MCP not run. |
| P06-V07 exclusion inspection | PASS | No instance, history, backup, personal or Node cache paths. |

WiX ICE passed for both review MSIs and the final candidate. Their logical
contents match, but binary hashes differ; MSI byte reproducibility is therefore
explicitly false and not converted to PASS.

Regression evidence: P05 local tags passed 80 checks; aggregate Harness passed
under PowerShell 7.6.5 and Windows PowerShell 5.1; Node provider tests passed
4/4. Soft context-budget warnings and the host's unavailable real symlink
capability remain warnings/blockers, not packaging passes.
