# Risk engine R0–R4

Classify the security risk of the *change*, not the size of the diff.

## R0 — No executable impact

Examples:

- documentation only;
- spelling/content without templating or HTML execution implications;
- formatting-only changes.

Default mode: no security gate or `FAST` if uncertainty exists.

## R1 — Low

Examples:

- CSS/layout;
- non-sensitive presentation logic;
- isolated internal helper without user input, auth, persistence or network effects.

Default mode: `FAST`.

## R2 — Moderate

Examples:

- ordinary forms and CRUD;
- validation changes;
- new UI behavior connected to backend persistence;
- normal database reads/writes;
- new library/dependency without privileged capability;
- non-sensitive API endpoints.

Default mode: `STANDARD`.

## R3 — High

Escalate when any of these are touched:

- login/logout/session/password reset/MFA;
- roles, permissions, ownership or tenant isolation;
- admin actions;
- direct SQL/query construction or migrations affecting security invariants;
- upload/download/import/export;
- webhooks or external requests derived from user input;
- email/SMS actions with user-controlled headers/recipients/content;
- REST/AJAX endpoints that mutate data;
- JWT/OAuth/OIDC/SAML;
- CORS/CSRF/security headers/cookies;
- deserialization, dynamic includes or template execution;
- `.github/workflows`, deployment credentials or CI permissions;
- sensitive personal/business data.

Default mode: `DEEP`.

## R4 — Critical/release-sensitive

Escalate when any of these apply:

- payments, balances, credits or financial state;
- privilege elevation or super-admin controls;
- cryptographic key generation/storage/verification;
- secret management or credential rotation;
- multi-tenant isolation changes;
- command/shell/process execution influenced by input;
- unsafe deserialization or code evaluation paths;
- public upload leading to executable/content delivery risk;
- broad auth middleware/router changes affecting many endpoints;
- production release/preproduction audit;
- security tooling/CI gate disabled or weakened;
- change exposes high-volume or highly sensitive data.

Default mode: `RELEASE` for a release task, otherwise `DEEP` with release-grade gates on the affected surface.

## Scoring tie-breaker

When several signals exist, prefer the highest level. Never average a critical signal down.

Use impact questions:

1. Can an unauthenticated actor reach it?
2. Can one normal user affect another user or tenant?
3. Can it change privileges or security settings?
4. Can it read/export sensitive data?
5. Can it cause irreversible/external effects?
6. Can it execute code/commands or access filesystem/network destinations?
7. Does failure propagate across many routes/users?
8. Does the change weaken a defense rather than add functionality?

Two or more strong "yes" answers normally justify at least R3.
