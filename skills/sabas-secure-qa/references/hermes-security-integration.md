# Hermes Agent integration — V0.5.4

Hermes can use the same `SKILL.md` workflow as Codex. Sabas Secure Development V0.5.4 installs the three first-party skills and `usuario-torpe-qa` in `~/.hermes/skills/` (or `$HERMES_HOME/skills/`).

Plugin discovery is verified primarily with `hermes plugins list --plain --no-bundled` so Rich table truncation cannot create a false `DEGRADED` result. Alternate-home cleanup is backup-first and only removes copies whose Sabas ownership can be proven.

The Hermes-specific enforcement layer is the user plugin `sabas-secure-development` under `~/.hermes/plugins/`.

## Native guardrails

The plugin registers:

- `pre_tool_call`: evaluates sensitive terminal commands and writes. Catastrophic disk/root deletion is blocked; dangerous but potentially legitimate operations are escalated to Hermes' existing human-approval gate. The hook does not log full command contents or secret values.
- `pre_verify`: after code edits, classifies the current repository using `security_context.py`. For R2/R3/R4 it requires a current `SABAS_SECURITY_VERDICT` and matching `SABAS_SECURITY_FINGERPRINT` before the turn may finish.

Hermes' own `agent.verify_on_stop` should be set to `auto` so interactive coding surfaces require fresh build/test/lint evidence while messaging surfaces avoid unnecessary verification chatter.

## Interaction with Sabas Secure QA

For R2+ changes the intended sequence is:

1. Hermes edits code.
2. Built-in verify-on-stop checks for fresh verification evidence.
3. The Sabas `pre_verify` hook checks the risk class and final receipt.
4. If the receipt is missing or stale, Hermes receives a continuation instruction.
5. `sabas-secure-qa` performs the applicable layered checks and remediation.
6. `security_context.py` is run again immediately before final output.
7. The final answer includes exactly one verdict line and one matching fingerprint line.

Do not treat the plugin as a security boundary by itself. It complements tests, SAST/SCA, secret scanning, authorization review, the threat model and controlled `usuario-torpe-qa` testing.

## Tool Guard policy

Hard block is deliberately narrow. It is reserved for obviously catastrophic commands such as recursive deletion of a filesystem root or direct disk formatting/wiping.

Human approval is requested for operations such as destructive Git history/worktree commands, force-push, destructive SQL, globally writable permissions, remote-code piping into a shell, explicit `.env` reads, security-policy weakening, or direct writes to sensitive agent/security configuration.

This keeps the guard useful without turning normal development into a constant approval loop.
