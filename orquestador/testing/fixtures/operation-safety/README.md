# Operation safety fixtures

`scripts/validate-operation-safety.ps1` owns the generated `.runtime/` child.
The validator creates `.hebrinex-operation-fixture` markers before injecting a
process termination and refuses cleanup when its root marker is absent.

The fixture never targets a consumer project. Child processes only write test
descriptors, approvals, locks, journals, results and witness files below the
marked `.runtime/` directory.
