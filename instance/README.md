# Hebrinex Instance State

`instance/` is the canonical per-project area introduced in 0.17.0.

Consumers must keep this directory as a real project-local copy. Do not junction,
symlink or share it between projects.

Legacy 0.16.x paths remain read-compatible during migration through
`SHARED_MANIFEST.yaml:instance_path_map`.
