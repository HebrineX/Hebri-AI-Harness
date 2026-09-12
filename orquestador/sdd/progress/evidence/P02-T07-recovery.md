# P02-T07 - Interrupted operation recovery

`Get-HebriOperationStatus` is read-only. It reports stored and effective state and derives `recovery_required` when a prepared/applying/rolling-back journal has a missing, dead, reused or unverifiable owner.

Recovery is a distinct operation named `recover:<original_operation_id>` with its own descriptor, write-set and human approval. It refuses a live original owner, marks only a verified orphan lock as recovered, acquires its own overlapping lock and restores each resource only when the current hash equals either the planned original or the recorded published hash. A third-party change yields `PRECONDITION_CHANGED` instead of overwrite.

Recovery consumes its own approval before marking `rolled_back`. If rollback fails while `rolling_back`, the journal returns to `recovery_required`. Repeating recovery against a terminal journal returns a full `operation_result` without another business write.

P02-V04 terminated real child processes after prepared, backup, publish, before commit and after approval consumption. All five invocations were detected as recovery-required and restored the original hashes. PowerShell 7 reported fixture exit code 91; Windows PowerShell 5.1 reported process exit code 0 for `Environment.Exit`, but in both hosts the processes terminated and the journal/hash oracle passed.
