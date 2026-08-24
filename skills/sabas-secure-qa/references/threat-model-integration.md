# Threat-model integration

Use `SECURITY-THREAT-MODEL.md` as persistent security context when present.

## Detect staleness

Treat the model as needing refresh when a change alters any of:

- authentication/session mechanism;
- role/permission model;
- tenant/ownership boundary;
- sensitive data collected/stored/exported;
- external integration/webhook;
- major API entry point;
- upload/import/download mechanism;
- privileged/admin operation;
- deployment architecture/trust boundary.

## Derive tests from threats

For every affected abuse case ask:

1. What security property should hold?
2. At which trusted boundary is it enforced?
3. What negative test proves it?
4. What evidence would detect regression?

Examples:

- Threat: User A reads User B document. Property: ownership enforced server-side. Test: request B's ID with A's session returns deny/no data.
- Threat: role posted as `admin`. Property: privileged fields are allowlisted/ignored. Test: update payload containing role cannot change authorization.
- Threat: duplicate submit creates duplicate charge. Property: operation idempotent/atomic. Test: repeated same intent produces one state transition.
- Threat: webhook spoofing. Property: signature/replay validation before mutation. Test: missing/invalid signature cannot change state.
