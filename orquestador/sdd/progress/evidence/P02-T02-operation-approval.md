# P02-T02 - Operation descriptor and scoped approval

Contract: `operation-safety/1`, version `1.0.0`.

The operation descriptor binds one `operation_id` to `project_id`, operation name, four resolved roots, exact write-set, code version, canonical plan/hash and one precondition hash per declared resource. Runtime validation rejects missing, duplicate, malformed, out-of-root or hash-inconsistent preconditions.

The scoped approval binds its `approval_id` to the descriptor hash, operation/project identities, plan, roots, write-set, code version, expiry and `same_operation_id` retry scope. It also records the human decision and evidence identifier. It cannot authorize another project, operation, plan, resource set or version.

Consumption is durable: successful publication marks the approval `consumed` before journal commit. A consumed approval cannot start or mutate a non-terminal operation. Idempotent recovery may inspect a terminal journal using the same consumed recovery approval without creating another lock or business write.

Adversarial P02-V03 proves that fake, expired, consumed, foreign, changed-plan and cross-bound approvals are rejected while the business witness hash remains unchanged. The approval-lock-journal chain must carry the same approval ID.

Schemas:

- `orquestador/runtime/schemas/operation-descriptor.schema.json`
- `orquestador/runtime/schemas/scoped-approval.schema.json`

Trust boundary: the local filesystem owner can still tamper with stores. ACL/installer ownership and authenticated host issuance are P06/P08 concerns; no cryptographic authority is claimed by P02.
