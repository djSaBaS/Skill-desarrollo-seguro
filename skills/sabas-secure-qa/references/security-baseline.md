# Practical security baseline — OWASP ASVS 5.0.0 aligned

This is a practical routing baseline, not a reproduction of the full ASVS standard.

## 1. Input, encoding and injection

- Treat all request, route, query, form, JSON, header, file and external-service data as untrusted until validated.
- Validate type, length, range, enum/state and business constraints server-side.
- Parameterize SQL; do not concatenate user-controlled data into queries.
- Keep command/process execution away from untrusted input; avoid shell expansion.
- Encode/escape output for its exact HTML/attribute/URL/JS/CSS context.
- Avoid unsafe `eval`, dynamic code execution and unsafe deserialization.

## 2. Authentication and credential lifecycle

- Use established framework/platform primitives for password hashing and auth.
- Do not leak whether sensitive accounts exist when that creates abuse risk.
- Reset/invite/verification tokens must be unpredictable, scoped, expire and become unusable after appropriate use.
- Re-authenticate for high-impact account/security changes when appropriate.
- Prevent login/session flows from trusting client-provided role/identity fields.

## 3. Session/token security

- Cookies carrying session state should use appropriate `Secure`, `HttpOnly` and `SameSite` controls.
- Regenerate session identifiers after privilege/auth transitions where applicable.
- Implement logout/revocation semantics appropriate to the token/session model.
- Validate JWT algorithm, issuer, audience, expiry and key selection; do not accept unsigned/algorithm-confused tokens.

## 4. Authorization

- Authenticate first, authorize every sensitive operation server-side.
- Enforce object-level ownership/tenant checks, not only function-level roles.
- Default-deny privileged operations.
- Do not rely on hidden buttons, route names or client-side roles.
- Protect mass-assignment: allowlist mutable fields, especially role/status/owner/tenant fields.

## 5. CSRF, CORS and browser boundaries

- State-changing cookie-authenticated requests require CSRF defenses suitable for the framework.
- CORS origins/methods/headers/credentials must be narrow and intentional.
- Do not combine wildcard origins with credentialed access.
- Review framing/CSP/content-type/referrer/HSTS headers according to deployment context.

## 6. Data protection and privacy

- Minimize sensitive data returned by APIs and exposed to frontend code.
- Never log passwords, bearer tokens, session IDs, private keys or full secrets.
- Apply access control to exports, reports and downloads.
- Use encryption/TLS appropriately; do not invent cryptography.
- Keep test data fictitious and clearly separated from production data.

## 7. File and path handling

- Enforce server-side size/count/type rules.
- Validate content/MIME where the threat warrants it; extension alone is weak evidence.
- Generate safe server-side filenames and prevent path traversal.
- Store untrusted files outside executable locations when possible.
- Authorize downloads by resource, not only by knowing a URL.
- Protect archives/importers from traversal, bombs and dangerous embedded content where applicable.

## 8. HTTP/external requests/SSRF

- Validate URL scheme and destination when influenced by users.
- Prefer allowlists for fixed integrations.
- Prevent access to internal/metadata endpoints when arbitrary URLs are not required.
- Use timeouts, size limits and controlled redirects.
- Verify webhook authenticity and replay protection when offered by the provider.

## 9. Business logic and state transitions

- Recalculate authoritative totals/permissions/state server-side.
- Use transactions/locking/idempotency where concurrent/repeated actions can violate invariants.
- Prevent replay/double-submit for one-time operations.
- Enforce workflow prerequisites at the backend.
- Verify state transitions are legal for the caller and resource.

## 10. Error handling and logging

- Return useful user-facing errors without SQL, stack traces, filesystem paths or secrets.
- Log security-relevant events with enough context to investigate, but avoid sensitive payloads.
- Distinguish expected validation errors from server faults.

## 11. Dependencies and supply chain

- Prefer lockfiles and reproducible installs.
- Audit new/changed dependencies and their transitive impact.
- Avoid typosquatting/dependency confusion with internal package names.
- Review package install scripts/hooks for unusually privileged dependencies when risk is high.
- Generate/inspect SBOM on release when tooling and deployment justify it.
- Pin/secure CI actions and minimize workflow token permissions.

## 12. WordPress/PHP specifics

- Sanitize according to input type and validate semantic constraints.
- Escape late at output: `esc_html`, `esc_attr`, `esc_url` or contextual equivalent.
- Use WordPress nonces for CSRF protection, not authorization.
- Enforce capabilities with `current_user_can()` on privileged operations.
- REST routes need an intentional `permission_callback`.
- AJAX handlers need auth/capability/nonce decisions appropriate to the action.
- Use `$wpdb->prepare()` for dynamic SQL values.
- Do not trust uploaded filenames/MIME reported only by the client.
- Avoid dynamic `include/require`, `eval`, unsafe `unserialize`, and shell execution on untrusted input.
- Protect options/settings writes and validate values before persistence.

## 13. Python specifics

- Parameterize DB access.
- Avoid `pickle`/unsafe YAML loaders with untrusted data.
- Avoid `shell=True` with dynamic input.
- Use safe temporary-file/path handling.
- Configure framework debug mode off in production.
- Validate serializer/model fields to prevent over-posting/mass assignment.

## 14. API specifics

- Validate request schema and reject unexpected privileged fields.
- Enforce object-level and function-level authorization.
- Prevent excessive data exposure in response serializers.
- Apply pagination/rate/resource limits to abuse-prone endpoints.
- Treat IDs as references, not authorization proof.
- Protect authentication endpoints against brute-force/credential-stuffing according to risk.

## 15. Security verification discipline

- Every security control needs evidence: code path, automated test, runtime observation or scanner result.
- Validate scanner findings before severity/gating.
- Security fixes should add regression proof where practical.
- Record unknowns as `NOT VERIFIED` rather than converting uncertainty into PASS.
