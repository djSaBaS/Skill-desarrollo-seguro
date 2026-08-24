---
name: sabas-threat-model
description: Create or refresh a practical security threat model for a software repository. Use when starting a security-sensitive project, adding auth/roles/admin/APIs/uploads/payments/webhooks/sensitive data/multi-tenant behavior, changing trust boundaries, or preparing a deep/release security review. Produces or updates SECURITY-THREAT-MODEL.md with assets, actors, entry points, trust boundaries, authorization rules, abuse cases and concrete verification tests. Do not store secrets in the threat model.
license: MIT
compatibility: OpenAI Codex/Codex IDE or Hermes Agent with repository access.
metadata:
  author: Sabas + OpenAI
  version: "0.5.4"
  category: threat-modeling
---

# Sabas Threat Model

## Goal

Create security context that is specific enough to drive code review and tests, but small enough to remain maintainable.

## Workflow

1. Read active `AGENTS.md` instructions and relevant architecture/readme/configuration.
2. Inspect the repository to identify languages, frameworks, entry points, persistence and integrations.
3. Identify actors and roles from code/configuration rather than inventing them.
4. Identify sensitive assets and privileged state transitions.
5. Map trust boundaries: browser/server, user/admin, tenant/tenant, app/database, app/external service, public upload/storage, CI/deployment.
6. Enumerate high-value entry points: auth, reset/invite, admin, REST/AJAX, upload/import/export, webhook, jobs/CLI.
7. Record expected authorization rules and resource ownership.
8. Create abuse cases that represent realistic failure modes.
9. For each important abuse case, define at least one verification idea/test.
10. Write/update `SECURITY-THREAT-MODEL.md` using `assets/SECURITY-THREAT-MODEL.md` as structure.
11. Preserve user-maintained decisions and accepted risks. Update only sections affected by evidence.
12. Never put credentials, tokens, cookies, private keys or real sensitive data in the model.

## Quality rules

- Prefer concrete names of application components and roles.
- Separate facts found in code from assumptions.
- Mark unresolved architecture assumptions explicitly.
- Do not turn the model into a generic OWASP checklist.
- Prioritize abuse cases with cross-user, privilege, sensitive-data, external-effect or irreversible impact.
- Keep historical update notes so later reviews can see why the model changed.

## Output

When file modification is in scope, create/update `SECURITY-THREAT-MODEL.md`.

Then summarize:

- highest-value assets;
- main trust boundaries;
- top abuse cases;
- assumptions needing confirmation;
- tests that `sabas-secure-qa` should prioritize.
