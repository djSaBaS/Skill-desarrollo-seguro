---
name: sabas-efficient-development
description: >-
  Minimize unnecessary token, context and tool usage while developing,
  debugging, reviewing or maintaining an existing codebase. Narrow broad
  requests into small verifiable batches, reuse existing diagnostics, avoid
  duplicate scans and background work, verify narrowly first, and expand only
  when evidence requires it. Never bypass required security or correctness checks.
license: MIT
compatibility: >-
  Agent Skills open standard; designed for OpenAI Codex, Google Antigravity
  IDE/CLI, Hermes Agent and ChatGPT Skills.
metadata:
  author: Sabas + OpenAI
  version: "0.2.0"
  category: efficient-development
---

# Sabas Efficient Development

## Mission

Solve development tasks with the smallest reliable amount of context, file
reading, tool usage and repeated work. Optimize waste, not quality.

A broad request is not permission for unlimited exploration. Before using tools,
convert it into the smallest useful execution batch.

## Priority rules

1. Obey project instructions and higher-priority safety/security requirements.
2. Never skip a required test, security gate, migration check or validation to save tokens.
3. Do not broaden the task into unrelated refactors, cleanup or audits.
4. Reuse current-session context and evidence supplied by the user.
5. Never claim a check passed unless it was executed or directly verified.
6. Prefer one finished, verified batch over partially exploring many areas.

## Scope compiler

Before calling tools, determine the requested outcome, strongest existing
evidence, smallest affected component, first independently verifiable batch and
the conditions that would justify expanding scope.

For open requests such as "fix the errors", "start correcting Sonar", "improve
the project" or "review what is wrong", do not perform a full repository audit
unless explicitly requested.

Default open-remediation budget:

- one root cause or at most three closely related findings;
- at most five production files unless correctness genuinely requires more;
- only directly related tests/checks;
- stop after that batch and report the next recommended batch.

Tests, fixtures and concise proof/documentation do not count as production files.

These are default budgets, not correctness limits. Before materially exceeding
them, pause and explain why unless the user explicitly requested autonomous broad
work.

## Modes

### ECO

For a named file, symbol, error, diff or small change. Do not map the repository.
Use at most one dependency hop when possible, verify narrowly, then stop.

### STANDARD

For interacting components or uncertain local scope. Search first, identify the
dependency path, then open only required files. Apply the default remediation
budget to open-ended work.

### DEEP

Only for explicit full audits/releases, architecture changes, systemic bugs,
migrations or evidence that proves broad analysis is necessary.

Do not choose DEEP because the repository is large, an issue is tagged
"security", or a deep scanner/subagent is available. Before escalating from
ECO/STANDARD to materially broader reads, scans or agents, request approval
unless that depth was already requested.

## Existing evidence first

Reuse current SonarQube findings, CI/test output, compiler/linter errors, stack
traces, PR findings and completed scans.

Do not rerun an equivalent repository-wide analysis merely to rediscover current,
specific findings. Rerun only when needed to verify the fix, when evidence is
stale/ambiguous, or when a required gate demands it. Prefer targeted rechecks.

## Repository workflow

1. Reuse known context.
2. Inspect status/diff first when relevant.
3. Search exact filenames, symbols, routes, tables, errors or config keys.
4. Open only relevant files/sections.
5. Expand one dependency hop at a time.
6. Make the smallest correct change using existing project patterns.
7. Run the narrowest meaningful check first.
8. Expand checks only when risk, policy or failed evidence requires it.
9. Stop when the current batch is complete and verified.

Avoid `node_modules/`, `vendor/`, generated output, full lockfiles, large logs and
Git history unless relevant. Do not reread unchanged files already understood or
rerun successful checks unless affected code changed.

## Tool and agent budget

By default, do not launch repository-wide/deep scans, background analysis,
parallel subagents, full test suites, full history inspection or unrelated
finding inventories for a local remediation task.

Do not automatically continue into the next remediation batch.

Use parallelism only when tasks are independent and broader autonomous work was
requested or approved.

If automatic context compaction occurs, finish the smallest already-started
verified batch and avoid optional new exploration. Never rescan the repository
merely to reconstruct lost context.

## Prompt narrowing

Interpret broad prompts conservatively:

- "Fix the Sonar errors": use existing findings, fix the highest-priority related
  batch, verify, report and stop.
- "Improve this module": improve the smallest area tied to the requested/problem
  behavior; no opportunistic cleanup.
- "Review everything before release": DEEP breadth is allowed, but still phase
  work and avoid duplicate reads/scans.

## Security coordination

This skill is an efficiency layer, not a security bypass.

When `sabas-secure-qa` applies, its risk classification and mandatory gates take
priority. Within those gates, reuse current scanner evidence, avoid duplicate
scans, prefer change-focused review for normal remediation, and reserve
repository/deep security scanning for release/high-risk cases or evidence that
requires broader investigation.

## Output and stop

Keep progress concise. Normally report what changed, affected files/components,
checks actually executed, unresolved risks/not-verified items and the next
recommended batch.

Stop when the bounded batch is solved and verified and applicable gates are
satisfied. Do not silently continue with the next batch.
