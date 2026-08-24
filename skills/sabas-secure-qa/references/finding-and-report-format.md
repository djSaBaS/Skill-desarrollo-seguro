# Finding and report format

## Finding fields

Each material finding should include:

- `ID`
- `Title`
- `Severity`: CRITICAL/HIGH/MEDIUM/LOW/INFO
- `Confidence`: CONFIRMED/HIGH-CONFIDENCE/POTENTIAL/NOT-VERIFIED
- `Origin`: INTRODUCED/AFFECTED/PRE-EXISTING
- `Component/endpoint/file`
- `Security property violated`
- `Evidence`
- `Reproduction/verification`
- `Impact`
- `Root cause`
- `Remediation`
- `Regression test`
- `Retest status`
- `Risk acceptance ID` when applicable

Never include full secrets, session cookies, private tokens or sensitive test data.

## Final report skeleton

```text
# Sabas Secure QA
Mode: FAST | STANDARD | DEEP | RELEASE
Risk: R0-R4
Verdict: PASS | PASS WITH WARNINGS | BLOCKED

## Scope
...

## Threat-model impact
...

## Verification matrix
| Check | Status | Evidence |
| ... | PASS/FAIL/NOT VERIFIED/N/A | ... |

## Findings
...

## Remediation applied
...

## Regression/retest
...

## Remaining debt / accepted risks
...

## Dynamic usuario-torpe-qa
Executed / Not applicable / NOT VERIFIED (reason)
```

## Concision

For ordinary code changes, keep the user-facing report compact and link/reference detailed artifacts if the repository workflow stores them. For `RELEASE`, provide enough evidence to support the gate decision.
