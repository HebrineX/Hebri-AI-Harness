# P02-T05 - Safe single-file publication

`Publish-HebriAtomicFile` requires an exact descriptor resource, the approved descriptor precondition, the matching approval-bound lock and a matching prepared journal. A caller-provided hash cannot replace the hash approved in the descriptor.

The publisher:

1. Revalidates descriptor, approval, lock, journal binding and precondition.
2. Records `applying`, creates a checksum-addressable journal resource and same-instance backup.
3. Stages content in the destination directory and flushes it.
4. Revalidates the target immediately before `File.Replace` or same-volume move.
5. Records the published hash, consumes the approval and only then marks `committed`.

P02-V06 changed the target after planning. The operation returned `PRECONDITION_CHANGED`, preserved the concurrent edit, and separately rejected an attempt to pass the new hash as if it were approved.

This contract provides atomic replacement for one file on the same volume. Multi-file workflows use ordered journal entries and deterministic compensation; P02 does not claim global or cross-volume atomicity.
