# Security policy

Sabas Secure Development is a defensive development workflow for Codex and Hermes Agent. It reduces risk through layered checks; it does not guarantee that software is vulnerability-free.

## Reporting a vulnerability in this repository

Do not publish real credentials, private keys, personal data, exploit payloads against third parties, or other sensitive evidence in a public issue. Prefer a private GitHub security advisory when the repository is public and that feature is available.

A useful report should include the affected component/version, security impact, the smallest safe reproduction, expected behaviour, observed behaviour, and a suggested mitigation when known.

## Safety boundary for dynamic tests

`usuario-torpe-qa`, DAST and destructive/error-recovery tests require explicit confirmation that the target is local, sandbox or staging under the tester's control, contains no real data that could be harmed, and permits create/modify/delete operations. Installation of this repository never grants that authorization.

## Supply chain

Optional third-party security skills are not vendored. Their repository and exact commit are pinned in `EXTERNAL-SKILLS.lock.json`, and only the allowlisted folders are installed after validation. Provenance is written alongside installed external skills.

## Security verdicts

A `SABAS_SECURITY_VERDICT: PASS` is scoped to the repository state named by `SABAS_SECURITY_FINGERPRINT`. Any relevant source change invalidates the prior receipt and requires re-evaluation.
