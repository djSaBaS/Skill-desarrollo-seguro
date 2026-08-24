# Security gates

## Blocking by default

The following block `PASS` when introduced or directly affected by the current change:

- Confirmed/high-confidence Critical.
- Confirmed/high-confidence High.
- Real credential/token/private key/secret committed or printed unsafely.
- Missing server-side authentication/authorization for a sensitive operation.
- Cross-user/cross-tenant access not explicitly intended.
- SQL/command/code injection with reachable untrusted input.
- Unrestricted executable upload or path traversal enabling sensitive file access.
- Security regression tests failing.
- Existing relevant tests failing because of the change.

## Release-only expansion

For `RELEASE`, also block when:

- a reachable/relevant Critical/High vulnerable dependency remains without a valid acceptance;
- CI/deployment change grants materially excessive token/workflow permissions;
- required lockfile or reproducible dependency state is broken without justification;
- the project handles secrets but obvious secrets scanning is absent and cannot be compensated by another verified check;
- auth/permission behavior cannot be meaningfully verified and the release depends on the changed behavior;
- a known High/Critical accepted risk has expired.

## Risk acceptance

Look for `SECURITY-RISK-ACCEPTANCE.md` or the file configured in `.sabas-security.yml`.

A valid acceptance includes:

- stable ID;
- finding and severity;
- exact scope;
- rationale;
- compensating control if any;
- who/what decision accepted it;
- date and expiration.

Rules:

- Never invent acceptance on the user's behalf.
- Critical requires explicit user/responsible-party decision.
- An expired acceptance is invalid.
- Broad statements like "known issue" are not sufficient.
- A scanner suppression without a traceable reason is not a valid acceptance.

## NOT VERIFIED semantics

`NOT VERIFIED` is not a failure by itself for normal development when another strong control covers the same risk, but it prevents claiming that specific check passed.

For release-critical auth/authorization or destructive external effects, missing verification may itself justify `BLOCKED` until evidence is available.

## Pre-existing findings

For ordinary change review:

- report pre-existing Critical/High findings clearly;
- block if the change makes them reachable, worsens them or relies on the vulnerable component;
- do not silently expand a tiny task into an unlimited legacy remediation project.

For `RELEASE`:

- unresolved reachable/relevant pre-existing Critical/High findings are blockers unless explicitly accepted.
