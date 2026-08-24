---
name: sabas-secure-qa
description: Secure-by-default gate for code changes and releases. Use whenever Codex or Hermes creates, modifies, refactors or reviews executable code in web/PHP/MySQL/WordPress/JavaScript/TypeScript/Python/API projects, especially auth, permissions, admin, uploads, SQL, secrets, CI/CD or sensitive data. Classify change risk, use the project threat model, coordinate installed defensive security skills and usuario-torpe-qa, validate findings, fix blocking issues, retest and return PASS/PASS WITH WARNINGS/BLOCKED. Do not use for documentation-only changes or unauthorized offensive testing.
license: MIT
compatibility: OpenAI Codex/Codex IDE and Hermes Agent. Dynamic testing requires an explicitly confirmed local, sandbox or staging environment. External scanners and skills are optional; missing coverage must be reported as NOT VERIFIED.
metadata:
  author: Sabas + OpenAI
  version: "0.5.4"
  category: secure-development
---

# Sabas Secure QA

## Mission

Make security a completion condition, not a cosmetic final checklist.

For code-changing tasks, act in a closed loop:

`understand -> classify risk -> model threats -> develop/review -> verify -> validate findings -> remediate -> regression-test -> re-verify -> verdict`.

Do not claim that code is secure merely because scanners are clean. Do not claim a check passed when the tool or environment required to perform it was unavailable.

## Required references

Read only the references needed for the current task, but always read:

- `references/risk-engine.md`
- `references/security-gates.md`
- `references/security-baseline.md`

Read additionally when applicable:

- `references/local-skill-routing.md` when other local skills are present.
- `references/external-skill-routing.md` when external cybersecurity skills are installed.
- `references/codex-security-integration.md` when the official Codex Security plugin/capabilities are visible in the current surface.
- `references/hermes-security-integration.md` when running under Hermes or reviewing its native gate behavior.
- `references/usuario-torpe-integration.md` for UI/dynamic testing.
- `references/threat-model-integration.md` for R3/R4 changes or when `SECURITY-THREAT-MODEL.md` exists.
- `references/finding-and-report-format.md` whenever producing an audit/release result.

## Phase 0 — Obey project instructions and determine scope

1. Read the active project context (`.hermes.md`, `AGENTS.override.md` or `AGENTS.md` as applicable) and repository documentation relevant to the change.
2. Determine whether the user requested implementation, review-only, remediation, preproduction validation or release validation.
3. Inspect the actual diff/current state rather than relying on a narrative of what was changed.
4. Preserve functional requirements. A security fix that silently breaks the required behavior is not a valid fix.
5. If the task is audit-only, do not modify code unless the user subsequently requests remediation.
6. If the task creates or modifies code, remediation of blocking findings is in scope unless explicitly excluded.

## Phase 1 — Build deterministic context

Prefer running `scripts/security_context.py --repo <repository>` from this skill directory when Python is available.

Use its output as evidence, not as a substitute for reasoning. Confirm important conclusions against the repository.

Identify:

- stack and frameworks;
- changed files and affected components;
- auth/authz/session surface;
- user-controlled input and output contexts;
- SQL/data persistence;
- file upload/download/import/export;
- external HTTP/webhooks/email/payment effects;
- secrets/configuration;
- dependencies/lockfiles;
- CI/CD and deployment changes;
- tests and available security tooling.

## Phase 2 — Classify risk and choose review mode

Use `references/risk-engine.md`.

Modes:

- `FAST`: R0/R1 low-risk change. Diff-focused checks and relevant tests.
- `STANDARD`: R2 normal application change. Static review + dependency/secret checks when relevant + tests.
- `DEEP`: R3 high-risk change. Threat-model check + focused security skills + stronger negative tests + dynamic QA when safe.
- `RELEASE`: R4 or explicit release/preproduction review. Full applicable gates, broader dependency/supply-chain review, threat-model validation and authorized dynamic testing.

Never downgrade a mode merely to save time. Escalate automatically when the changed behavior touches a higher-risk surface.

## Phase 3 — Use or refresh the threat model

For R3/R4 changes:

1. If `SECURITY-THREAT-MODEL.md` exists, read the relevant sections.
2. If it is missing, construct a minimal in-memory model before reviewing; for persistent setup, use `sabas-threat-model` or `sabas-security-bootstrap`.
3. Identify assets, actors, entry points, trust boundaries, privileged operations and abuse cases affected by the change.
4. Verify that the implementation enforces the security property at the server/trusted boundary, not only in the UI.
5. If the change materially alters auth, roles, sensitive data, APIs, integrations or trust boundaries, update the project threat model when modification is in scope.

## Phase 4 — Coordinate skills; do not duplicate blindly

If these local skills are available, use the minimal applicable set and read their `SKILL.md` before following them:

- `web-code-quality-php-mysql-js-v2`: development/code-quality rules.
- `web-security-audit`: focused web security audit.
- `web-test-validator`: final regression/validation.
- `usuario-torpe-qa`: real-browser misuse testing in a confirmed controlled environment.

Use external skills only when their narrow specialty matches the risk. Follow `references/external-skill-routing.md`.

When the official Codex Security layer is available in Codex, use it according to `references/codex-security-integration.md`: prefer change review for R2/R3 diffs and repository/deep scanning for high-risk RELEASE work when appropriate. Treat it as additional evidence, not as a substitute for deterministic tests, secret/SCA checks or dynamic QA.

Do not invoke exploitation/evasion/post-exploitation skills merely because they exist.

## Phase 5 — Run layered verification

Apply checks in this order when relevant:

1. Syntax/build/type checks already used by the project.
2. Existing unit/integration/end-to-end tests affected by the change.
3. Secret detection and review of accidentally committed sensitive material.
4. SAST/security linting using existing tools or selected skills.
5. Official Codex Security change review when available and justified by the risk/mode.
6. SCA/dependency audit from lockfiles and manifests.
7. Manual security review against `references/security-baseline.md`.
8. Targeted negative/security tests derived from the threat model.
9. Dynamic browser/API validation in a controlled environment.
10. DAST only against explicitly authorized local/staging targets.
11. Release-only checks such as SBOM/build/CI/supply-chain controls and, when available, broader Codex Security repository/deep scanning for high-risk components.

Prefer existing project commands. Do not add production dependencies solely to run a scanner.

If a useful security tool is unavailable, mark that check `NOT VERIFIED` and continue with alternative evidence.

## Phase 6 — usuario-torpe-qa integration

When a rendered UI or admin workflow is relevant, follow `references/usuario-torpe-integration.md`.

Important sequencing:

1. Complete the `usuario-torpe-qa` audit without modifying code during that audit.
2. Collect reproducible findings.
3. Return findings to this orchestrator.
4. Correlate functional/UX findings with security impact.
5. Apply fixes when remediation is in scope.
6. Rerun the affected torpe scenarios and normal happy path.

Never fabricate browser results when no browser is available.

## Phase 7 — Validate and classify findings

For every candidate finding distinguish:

- `CONFIRMED`: reproduced or proven by direct code/data-flow evidence.
- `HIGH-CONFIDENCE`: strong code evidence but runtime reproduction unavailable/unnecessary.
- `POTENTIAL`: plausible but insufficient evidence; investigate further where reasonable.
- `FALSE-POSITIVE`: disproven.
- `NOT-VERIFIED`: required verification could not be executed.

Also tag origin:

- `INTRODUCED`: created by the current change.
- `AFFECTED`: pre-existing weakness directly touched/exposed by the change.
- `PRE-EXISTING`: outside the changed surface.

Do not copy scanner severity blindly. Re-evaluate severity using real impact, exposure, privileges required, data sensitivity, tenant/role boundaries and recoverability.

## Phase 8 — Security gate

Apply `references/security-gates.md`.

At minimum, block completion when:

- the change introduces or affects a confirmed/high-confidence `CRITICAL` or `HIGH` finding;
- a real secret is present in source/history/output and has not been handled safely;
- an authorization boundary for a sensitive action is missing or client-only;
- relevant tests fail because of the change;
- a security fix has not been retested;
- the release review has a Critical/High dependency vulnerability that is reachable/relevant and lacks explicit accepted-risk treatment;
- required release checks are represented as passed despite not being executed.

## Phase 9 — Remediate root cause

For implementation/remediation tasks:

1. Fix the root cause rather than masking symptoms.
2. Prefer central authorization/validation controls when multiple endpoints share the same rule.
3. Keep output encoding contextual.
4. Keep authorization server-side and resource-specific.
5. Parameterize data access.
6. Avoid adding suppressions unless the finding is disproven or has a recorded risk acceptance.
7. For a real exposed secret, redact it from reports, remove it from code, determine whether Git history contains it, and state that rotation/revocation is required when exposure was possible.
8. Avoid broad refactors unless necessary for a safe fix.

## Phase 10 — Add regression proof

For each fixed Critical/High and whenever practical for Medium:

- add or update a regression test that fails before the fix and passes after it;
- include negative authorization/validation cases, not only happy paths;
- for business logic issues, test the invariant that was violated;
- for duplicate/race/state issues, test idempotency or state transition constraints where feasible.

Do not create fragile tests that merely encode implementation details.

## Phase 11 — Re-verify and issue verdict

After fixes:

1. Rerun every check that detected the problem.
2. Rerun directly affected functional tests.
3. Rerun relevant security/negative tests.
4. Rerun affected `usuario-torpe-qa` scenarios if dynamic testing was used.
5. Confirm the normal user flow still works.
6. Re-evaluate findings rather than assuming the patch solved them.
7. Run `scripts/security_context.py --repo <repo>` again after every remediation and immediately before the final response.
8. Read its current `gate_fingerprint`; if the working tree changes after that run, discard the fingerprint, re-evaluate affected checks and run the context script again.

Return exactly one release verdict and two machine-readable lines so the optional completion hook can prove that the receipt belongs to the current change state:

- `SABAS_SECURITY_VERDICT: PASS`: applicable gates verified; no unresolved blocking finding.
- `SABAS_SECURITY_VERDICT: PASS WITH WARNINGS`: no blocking finding, but Medium/Low debt or explicitly documented NOT VERIFIED coverage remains.
- `SABAS_SECURITY_VERDICT: BLOCKED`: a security/reliability gate remains open.
- `SABAS_SECURITY_FINGERPRINT: <gate_fingerprint>`: copy the exact SHA-256 returned by the final `security_context.py` run.

Do not emit either marker unless the security gate was actually evaluated for the current executable change. Never reuse a fingerprint from an earlier state, earlier turn or earlier diff.

A `PASS` is not a guarantee of absolute security; it means the applicable V0.5.4 controls were executed successfully with the available evidence for the fingerprinted change state.
