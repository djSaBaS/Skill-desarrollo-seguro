# Five mandatory high-risk control families

This reference expands five recurring controls that require concrete evidence,
not just a keyword in an audit report:

- `SEC-ENV`: credentials out of code, with secrets in a private server-side `.env`;
- `SEC-PROD`: safe production secret lifecycle;
- `SEC-RATE`: IP/account/endpoint abuse and rate limits;
- `SEC-ROW`: per-user/per-tenant data isolation (RLS or application equivalent);
- `SEC-SESS`: sessions and tokens that actually expire.

The controls apply when the changed behavior touches the corresponding attack
surface, and to applicable components during a release. They do not license
unrelated full-repository scans during a small change. The baseline already
governs validation, hashing, cryptography, CSRF and CORS.

## Shared evaluation contract

For each applicable family report: `control ID`, affected routes/resources,
the trust boundary, `PASS | FAIL | NOT VERIFIED | NOT APPLICABLE`, a specific
code/config/test evidence pointer, negative tests and their actual result,
severity, and remediation/owner. A described test is not an executed test.

A family may be marked `PASS` only after applicable requirements are backed
by code inspection plus the strongest practical test/runtime evidence.
Never substitute an LLM claim, lint result or `SABAS_SECURITY_FINGERPRINT`
for runtime proof. Unavailable staging or credentials -> `NOT VERIFIED`;
do not open, quote, copy, upload or expose real `.env` contents to inspect
them. For a sensitive production release, see `security-gates.md`.

## SEC-ENV — secrets live in a private .env, never in source

### Requirements

1. In environments controlled by the project, store runtime credentials,
   API keys, database passwords, signing/encryption keys and provider tokens
   **only in the private server-side `.env`** (or environment variables
   securely injected from that deployment's `.env`). Do not put values in
   source, constants, JavaScript bundles, HTML, mobile APK assets, CSS, SQL
   dumps, config defaults, CI scripts, command arguments or documentation.
2. Keep `.env`, `.env.local`, `.env.production` and equivalent variants
   excluded from Git and release artefacts. A committed file is compromised
   even if later deleted: inspect history/CI/artifacts and rotate if exposed.
   `.env.example` may be versioned **only with key names and harmless blank
   placeholders, never usable values**.
3. Store the actual `.env` outside `public_html`/`www`/web document root;
   if deployment cannot do this, move it to a private server directory and
   have application bootstrap read that private path. Verify web URLs,
   path traversal, static file serving and misconfigured reverse-proxy
   locations cannot fetch it. Denying HTTP access is defense in depth, not
   a substitute for placing it outside the public root.
4. Restrict filesystem access to the runtime identity/authorized operators
   and protected backups. Do not assume `.gitignore` or the .env extension
   encrypts a file. Reject world-readable permissions where platform
   semantics permit; avoid insecure shared-hosting sibling-account access.
5. Load `.env` only on trusted server startup, reject missing/empty required
   secrets in production, and avoid insecure hard-coded fallback credentials.
   Do not parse untrusted `.env` content as executable shell/PHP code.
   Keep client-visible build-time `PUBLIC_*`/`VITE_*`/`NEXT_PUBLIC_*`
   variables free of secrets.
6. Do not echo, log, serialize, include in exceptions, return through APIs,
   display in debug pages, place in telemetry, send to AI tools or copy into
   tests/fixtures the values from `.env`. Prefer safe checks of *presence*
   and permissions without revealing actual values.
7. Use separate `.env` values and identities for local, staging and
   production. Use fake credentials in automated tests. Explicitly audit
   bootstrapping/deployment to ensure no secrets are copied into Docker
   layers, static bundles, distributable mobile packages or build artefacts.

### Negative verification

- Attempt a read of `/.env`, `/.env.production` and common encoded/static
  variants on **authorized local/staging**, expecting no secret disclosure.
- Inspect tracked paths, Git history, build output and secret-scanner
  findings without printing values; verify `.env.example` has no credential.
- Unset a required secret in an isolated test and require a safe startup
  failure with no credential or stack trace exposure.
- Confirm no client bundle or API response contains any server secret.

## SEC-PROD — production secret lifecycle

### Requirements

1. Preserve the `SEC-ENV` location and non-disclosure requirements in
   production. `.env` is storage, **not** itself encryption or a vault.
2. Ensure production uses distinct least-privilege database/API identities,
   production-only keys and a reviewable owner for each credential; never
   reuse developer, sandbox or staging credentials.
3. Provision the production `.env` through a controlled deployment channel,
   never commit it, attach it to an issue, include it in release ZIP/APK or
   print it in CI logs. If CI must provision it, use protected secrets/runner
   controls and avoid echo, tracing and long-lived workspace copies.
4. Disable debug/error-display/config-dump endpoints in production; scrub
   secrets and sensitive headers from errors, logs, traces, backups and
   monitoring. Set protected backups with appropriate retention.
5. Document rotation, expiration, revocation and emergency credential
   replacement, including employee departure and suspected compromise.
   Rotate possibly exposed secrets immediately and invalidate old tokens;
   record necessary coordinated key migration if ciphertext depends on them.
6. Ensure no insecure default/fallback value is accepted in production, and
   verify startup fails safely when a mandatory credential is unavailable.
7. Inspect production `.env` only via approved operational checks; the
   agent must not request or print raw credentials. Mark controls
   `NOT VERIFIED` if runtime access/evidence is missing.

### Negative verification

- Test safe failure for missing/invalid prod secret without disclosing it.
- Verify old credentials are rejected after a staged test rotation.
- Validate production debug/diagnostic routes do not reveal config.
- Check a deploy artifact and CI log sample for leaked credentials without
  publishing sensitive matches.

## SEC-RATE — IP, identity and endpoint rate limits

### Requirements

1. Threat-model login, password reset, OTP, invitations, anonymous forms,
   file uploads, public search, expensive APIs and bulk/export endpoints.
   Pick limits per endpoint and risk, not one arbitrary global threshold.
2. Enforce a server/edge-side **IP-based budget** where abuse warrants it,
   plus account/user/client-key/device or other identity budgets for sensitive
   endpoints; IP alone is inadequate behind NAT and against distributed
   attacks. Define a safe policy for legitimate shared IPs.
3. Derive the client IP from the connection or a **trusted-proxy chain** only
   when the proxy is explicitly configured. Reject spoofed
   `X-Forwarded-For`/`Forwarded` values sent directly by clients.
   Normalize IPv4/IPv6, consider IPv6 privacy address rotation and
   privacy-preserving retention of identifiers.
4. Use atomic/shared counters or an appropriate edge limiter for
   multi-process/multi-instance deployments; define window/burst, expiration
   and cleanup. Do not use race-prone local mutable counters as the sole
   production gate when traffic is distributed.
5. Provide predictable `429 Too Many Requests`, relevant `Retry-After`,
   generic authentication errors, capped retry behavior and no user/account
   enumeration. Consider backoff/temporary lockouts and abuse monitoring
   without creating trivial user-targeted denial of service.
6. Document exemptions and fail-open/fail-closed behavior under limiter-store
   outage. For auth or expensive endpoints, treat absence of effective
   protection according to demonstrated exposure and volume.
7. Couple limits to authorization, CSRF, input size, concurrency and
   resource-consumption safeguards; limiting frequency alone does not
   prevent expensive single requests.

### Negative verification

- Reproduce a burst from the same IP to trigger the configured limit.
- Verify a different authenticated account cannot bypass a sensitive
  per-account budget from the same or a different IP.
- Spoof `X-Forwarded-For` from an untrusted client; verify it does not reset
  the budget. Validate trusted-proxy operation separately.
- Repeat using parallel requests/multiple workers and IPv6 to detect races
  or bypasses; verify TTL/window recovery and response status.
- Verify shared-IP legitimate usage and excluded health checks do not produce
  disproportionate false positives; never load-test production without
  explicit authorization.

## SEC-ROW — user/tenant row-level isolation

### Requirements

1. Build an access matrix for anonymous, ordinary user, staff, admin and
   service roles with ownership, tenant and delegation rules. Row access
   must reflect **the authenticated server-side identity**, not a
   client-supplied `user_id`, tenant, role or hidden form field.
2. Enforce resource checks on **every** applicable read/write path:
   list, detail, search, count/aggregate, join, update, delete, batch,
   export, import, attachment, background job, webhook and API route.
   Check both record ownership and the action/role required.
3. In PHP/MySQL/MariaDB, where PostgreSQL-style native RLS is not
   available, implement the equivalent in **server-side query predicates
   and/or an audited centralized authorization layer**, including
   prepared SQL and scoped writes. A `WHERE id = ?` alone is insufficient;
   scoping must match verified tenant/owner/role policies. Do not rely on
   frontend filtering, encrypted/unguessable IDs or obscure URLs.
4. In databases that support native row-level security (e.g. PostgreSQL),
   enable and test policies using non-bypass runtime roles and the correct
   per-request principal/tenant context. Account for owner/BYPASSRLS
   exceptions, policy changes and pooled connection context leakage.
5. For legitimate staff cross-user access, require an explicit permission
   and purpose-specific scope, not a blanket role bypass. Default deny
   unknown owners/tenants, missing identity, malformed IDs and forbidden
   transitions. Consider timing/error differences and enumeration risk.
6. Ensure jobs, queues, cached responses and exported files do not leak
   data across tenants or users. Include the correct principal/scope in
   cache keys; recheck authorization on download and shared links.

### Negative verification

- Create **two distinct test users in different ownership scopes** and,
  where relevant, two different tenants. Test allowed and forbidden
  read/list/count/update/delete/export/download operations.
- Swap URL/resource IDs, body owner/tenant fields and batch IDs to verify
  server-side isolation, including crafted requests bypassing the UI.
- Verify admin/staff delegation is permitted only by documented policy;
  test privilege downgrade and revoked permissions.
- Test joins, aggregations, caches and queued work cannot cross scopes.
  On native RLS, test as the runtime role (not only database owner) and
  exercise transaction/connection reuse.
- Expected forbidden response is appropriate `403` or nonenumerating
  `404`; **no** cross-user data or modification is acceptable.

## SEC-SESS — expiration, invalidation and secure sessions

### Requirements

1. Configure a risk-based **server-enforced idle timeout** and an absolute
   maximum session lifetime. Document values and exceptions for
   administrative and normal users. Browser-side timers or idle UI overlays
   do not enforce server expiration.
2. Store authenticated `created_at`, `last_activity`, identity and
   revocation state in a trusted session store. Check both timeouts **before
   each protected request**; update last activity after a valid request with
   safe race/concurrency handling. Database/cache cleanup alone does not
   replace these checks.
3. In PHP, do not rely on `session.gc_maxlifetime` or cookie expiry as the
   only security control. Rotate the session ID on login and privilege
   change; configure session cookies as `Secure`, `HttpOnly` and
   `SameSite` according to CSRF/cross-site needs, with suitable path/domain.
4. Logout, password reset/change, role downgrade, account suspension and
   confirmed compromise must invalidate affected sessions/tokens promptly
   according to policy. Clear cookies/client state and invalidate the
   **server-side** session as needed; logout that only hides a page is invalid.
5. Set appropriate cache-control on authenticated responses and prevent
   sensitive cached pages from being reused after logout.
6. For JWT/API sessions, validate signature/algorithm, issuer, audience,
   `exp`, `nbf`, bounded `iat`/clock skew and key selection. Apply
   appropriate refresh-token expiration, rotation/reuse detection and
   server-side revocation for risk-sensitive flows; a JWT's signature alone
   does not guarantee logout.
7. For "remember me"/long-lived sessions, use separate scoped, revocable,
   hashed-at-rest tokens with explicit maximum lifetime and rotation,
   rather than disabling session expiration.
8. Defend against fixation and hijacking with TLS and secure cookies;
   reauthentication for high-impact operations when risk warrants.

### Negative verification

- Use a controlled clock or suitably isolated test to pass the idle
  timeout and absolute maximum, including activity before the absolute
  deadline. Verify expiration on the **server**, not just in the browser.
- Confirm logout, password reset, role change and session revocation
  invalidate old cookies/access tokens and prevent further privileged calls.
- Attempt a pre-login session ID after authentication; verify rotation.
- For JWT refresh, test expired, malformed, wrong-audience, revoked and
  replayed refresh tokens, including concurrent refresh attempts.
- Check browser restart/remember-me behavior and cookie attributes.

## Verdict and severity guidance

- `PASS` means each applicable rule was checked with appropriate evidence.
- `FAIL` means a demonstrated violation. Prioritize actual exploitability:
  exposed production secret, reachable cross-user data access, unbounded
  exposed auth abuse and bypassable protected sessions are usually
  Critical/High depending on impact.
- `NOT VERIFIED` means the required test/config/runtime evidence could not
  be obtained without unsafe access. It is **not** a `PASS`.
- `NOT APPLICABLE` needs an explanation based on the actual architecture.
- When modifying these security-sensitive surfaces, use DEEP or RELEASE
  as dictated by `risk-engine.md`. Resolve Critical/High affected findings
  before a PASS; releases require coverage of applicable controls or a
  documented, specifically scoped risk decision per `security-gates.md`.
- Test only in authorized local/staging environments; never publish secrets
  or carry out credential-guessing, stress testing or destructive tests on
  production without explicit approval.
