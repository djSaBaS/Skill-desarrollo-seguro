# usuario-torpe-qa integration

## Hard requirements

When `usuario-torpe-qa` is installed, read and follow its current `SKILL.md` rather than relying only on this summary.

The expected contract includes:

- real interaction through the available browser;
- explicit confirmation that the target is local/test-controlled before actions begin;
- fictitious identifiable test data;
- distinction between observed fact, expected result and inference;
- reproducible findings;
- verification after save/delete/reload/back navigation;
- no code modification during the torpe audit itself;
- no fake dynamic results when a browser is unavailable.

## When the orchestrator should request it

Use for R2+ UI flows when at least one applies:

- forms with persistence;
- admin settings;
- create/edit/delete workflows;
- role-dependent UI;
- AJAX requests;
- upload/import flows;
- multi-step workflows;
- operations susceptible to duplicate submission or accidental destruction.

Prioritize it for R3/R4 user-facing flows.

## Security-focused torpe scenarios

In addition to ordinary usability misuse, correlate these patterns with security:

- user clicks twice on state-changing operation -> idempotency/duplicate effect;
- browser back/reload after mutation -> replay/state mismatch;
- direct URL to admin/internal page -> server-side authorization;
- second tab edits same resource -> stale-write/concurrency;
- session expires mid-flow -> authorization and recoverability;
- user submits unexpected role/status/owner fields -> mass assignment;
- deleting/restoring records -> authorization and integrity;
- very long/special content -> validation/XSS/error leakage;
- upload unusual filename/type/size -> file handling;
- low-privilege user discovers hidden action -> broken access control.

## Sequencing rule

Do not let the implementation agent patch code in the middle of the torpe audit. Finish/reproduce the finding first. Then return to `sabas-secure-qa`, patch, and rerun the minimum reproducer plus happy path.

## No safe environment

If the user has not confirmed a controlled environment, continue static/code review and report dynamic coverage as `NOT VERIFIED`. Do not block all useful work merely because the dynamic phase is waiting for its safety gate.
