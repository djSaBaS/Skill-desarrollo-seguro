# Security policy

Sabas Secure Development is a defensive development workflow for OpenAI Codex, Hermes Agent and Google Antigravity IDE. It reduces risk through layered checks; it does not guarantee that software is vulnerability-free.

## Reporting a vulnerability in this repository

Do not publish real credentials, private keys, personal data, exploit payloads against third parties, or other sensitive evidence in a public issue. Prefer a private GitHub security advisory when the repository is public and that feature is available.

A useful report should include the affected component/version, security impact, the smallest safe reproduction, expected behaviour, observed behaviour, and a suggested mitigation when known.

## Runtime trust boundaries

The bundle has different enforcement levels depending on the agent:

- **Codex** can optionally install `sabas_secure_stop.py` as a Stop Hook. Codex correctly warns that hooks may execute outside the sandbox. Review the command before trusting it. The portable setup verifies that the installed hook is byte-identical by SHA-256 to the audited copy shipped in the bundle.
- **Hermes Agent** can install the native `sabas-secure-development` plugin. Its tool guard is defense in depth, not an operating-system sandbox.
- **Google Antigravity IDE** receives Agent Skills only. This repository does not install Codex hooks, Hermes plugins, MCP servers or additional Antigravity hooks as part of the Antigravity target.

A skill is an instruction layer, not a security boundary. Files, commands and network access available to the underlying agent remain governed by that agent and the operating system.

## Codex Stop Hook behaviour

The bundled Codex Stop Hook is deliberately narrow. It reads the hook event from standard input, invokes the local `security_context.py` classifier without a shell, applies a timeout, and evaluates the risk/fingerprint of the current repository state.

It does not download code, execute model-provided shell text or modify project files. If its classifier cannot be executed reliably, it fails open rather than creating an infinite stop loop.

`hooks.json` is normalized by the portable setup to UTF-8 without BOM because current Codex parsing can reject a Windows PowerShell 5.1 UTF-8 BOM at byte zero.

## Remote updater trust boundary

`Update-SabasSecureDev.ps1` downloads a public archive from `djSaBaS/Skill-desarrollo-seguro` and executes the included setup after extraction. Use it only when you trust that repository/ref.

`MANIFEST.sha256` detects accidental or partial modification inside a downloaded bundle, but it is not an independent cryptographic signature: the manifest and files are distributed from the same repository. For stronger change control, pin `-Ref` to a reviewed tag or commit and review the repository history before updating.

The updater does not use `curl | powershell`; it saves the archive to a temporary directory, requires a unique setup entrypoint and removes the temporary copy in `finally`.

## Safety boundary for dynamic tests

`usuario-torpe-qa`, DAST and destructive/error-recovery tests require explicit confirmation that the target is local, sandbox or staging under the tester's control, contains no real data that could be harmed, and permits create/modify/delete operations. Installation of this repository never grants that authorization.

## Efficiency is not a security bypass

`sabas-efficient-development` reduces redundant reads, scans, agents and tests, but it must not skip a required security gate, migration check, syntax/build check or regression test merely to reduce quota usage.

For localized remediation, reuse fresh Sonar/CI/test evidence and prefer focused verification. Repository-wide/deep scans remain appropriate for explicit release reviews, systemic risk or evidence that requires broader analysis.

## Supply chain

Optional third-party security skills are not vendored. Their repository and exact commit are pinned in `EXTERNAL-SKILLS.lock.json`, and only the allowlisted folders are installed after validation. Provenance is written alongside installed external skills.

The portable Antigravity target does not automatically install those external skills; they require separate runtime review before being enabled there.

## Security verdicts

A `SABAS_SECURITY_VERDICT: PASS` is scoped to the repository state named by `SABAS_SECURITY_FINGERPRINT`. Any relevant source change invalidates the prior receipt and requires re-evaluation.

A PASS is evidence that the applicable controls completed for that state. It is not proof that no unknown vulnerability exists.
