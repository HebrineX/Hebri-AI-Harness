# P02-T04 - Atomic operation locking

Operation locks are JSON records under the resolved project `InstanceRoot`. They contain operation/project/approval/descriptor identity, exact resources, PID, process start timestamp, process name, machine name, creation/expiry and status.

Acquisition serializes inspection and creation with a named mutex derived from the lock root, then publishes the lock with `FileMode.CreateNew`. Active path overlap includes exact, ancestor and descendant resources. A live owner yields `LOCK_BUSY`; dead, reused or unverifiable identity yields `LOCK_OWNER_UNVERIFIED` and is never stolen automatically. TTL is diagnostic only.

P02-V01 ran two real processes behind one barrier on the same resource: exactly one acquired and one was blocked. P02-V02 ran separate project/InstanceRoot contexts: both acquired without cross-project writes. P02-V05 forged a reused PID start identity: normal acquisition did not steal it, while separately approved recovery resolved it.

The validator itself now uses a unique marker-owned runtime root per process, so concurrent validation runs cannot delete each other's fixtures.
