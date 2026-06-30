# Harness Validator Fixtures

Fixtures are small positive and negative inputs used by local validators to
prove that hard rules fail closed. They are not runtime state.

Negative fixtures must be rejected by pattern or schema checks. Positive
fixtures must keep the minimum valid shape for the target domain.
