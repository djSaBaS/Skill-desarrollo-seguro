---
name: sabas-security-bootstrap
description: Bootstrap secure development controls in a repository for Codex or Hermes. Use when preparing a new/existing project to be secure-by-default, setting up project security files, CI security gates, SAST/SCA/secret scanning, release checks, or integrating Sabas Secure QA into a repo. Detect the actual stack first, create minimal relevant configuration, and avoid adding production dependencies solely for scanning.
license: MIT
compatibility: OpenAI Codex/Codex IDE or Hermes Agent. CI/tool setup may require network access and user authorization for external services.
metadata:
  author: Sabas + OpenAI
  version: "0.5.4"
  category: security-bootstrap
---

# Sabas Security Bootstrap

## Goal

Prepare a repository so secure behavior is repeatable and visible to Codex, developers and CI.

## Workflow

1. Read active project instructions and inspect the stack.
2. Run the `sabas-secure-qa/scripts/security_context.py` inventory if available.
3. Do not install or configure every scanner indiscriminately.
4. Create `.sabas-security.yml` from `assets/.sabas-security.yml` when absent, adapting only values known from the repository.
5. Create `SECURITY-THREAT-MODEL.md` via `sabas-threat-model` for R3/R4 projects or applications with auth/users/admin/data persistence.
6. Create `SECURITY-RISK-ACCEPTANCE.md` from `assets/SECURITY-RISK-ACCEPTANCE.md` when the project needs formal suppressions/exceptions.
7. Add a concise project `AGENTS.md` security section only when it does not conflict with existing guidance. Preserve existing content.
8. Detect existing test/lint/CI commands and reuse them.
9. Recommend or configure secret scanning, SAST and dependency scanning appropriate to the stack.
10. For GitHub Actions, review workflow token permissions and third-party action pinning; use `securing-github-actions-workflows` if installed.
11. For PHP/Composer, prefer Composer's existing audit capabilities plus SAST/secret scanning; do not pretend CodeQL covers PHP when it does not.
12. For JavaScript/TypeScript/Python, integrate ecosystem dependency checks and SAST using existing project conventions.
13. For Docker/IaC, add container/IaC scanning only when those artifacts exist.
14. Configure DAST only when there is a stable local/staging target and authorization to scan it.
15. For release workflows, consider SBOM generation where it adds real supply-chain value.
16. Do not add production/runtime dependencies just to implement security tooling; keep scanners in dev/CI tooling.
17. After changes, run the relevant config/test validation and `sabas-secure-qa` on the bootstrap changes themselves.

## Desired end state

A mature project should have, as applicable:

- `.sabas-security.yml`;
- `SECURITY-THREAT-MODEL.md`;
- `SECURITY-RISK-ACCEPTANCE.md`;
- secret scanning;
- SAST;
- dependency/SCA checks;
- security-aware CI permissions;
- regression tests for security invariants;
- controlled dynamic test environment;
- explicit RELEASE security gate before production.

Do not claim a control exists until its config/command/CI behavior is observable.
