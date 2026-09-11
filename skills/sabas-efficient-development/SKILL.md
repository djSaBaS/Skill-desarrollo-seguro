---
name: sabas-efficient-development
description: >-
  Minimize unnecessary token, context and tool usage while developing,
  debugging, reviewing or maintaining an existing codebase. Use the smallest
  reliable working set, search before reading, reuse known context, make
  focused changes, verify narrowly first, and expand only when evidence
  requires it. Never bypass required security, correctness or project checks.
license: MIT
compatibility: >-
  Agent Skills open standard; designed for ChatGPT Skills, OpenAI Codex and
  Hermes Agent. Works best when the agent can search repository files and run
  targeted tests.
metadata:
  author: Sabas + OpenAI
  version: "0.1.1"
  category: efficient-development
---

# Sabas Efficient Development

## Mission

Solve development tasks with the smallest reliable amount of context, file
reading, tool usage and repeated work. Optimize waste, not quality.

## Priority rules

1. Obey project instructions and higher-priority safety/security requirements.
2. Never skip a required test, security gate, migration check or validation to save tokens.
3. Do not broaden the task into unrelated refactors or cleanup.
4. Reuse information already available in the current session.
5. Never claim a check passed unless it was actually executed or directly verified.

## Working modes

### ECO

Use for small, well-bounded changes. Start from the named file, symbol, error or
diff. Do not map the whole repository.

### STANDARD

Use when several components interact or the affected area is not fully known.
Search first, identify the dependency path, then open only the required files.

### DEEP

Use only when evidence requires broad analysis, such as architecture changes,
systemic bugs, migrations, release validation or security-sensitive work.

Do not choose DEEP merely because the repository is large.

## Repository workflow

1. Reuse known context before calling tools.
2. Inspect status/diff first when relevant.
3. Search exact filenames, symbols, routes, selectors, tables, errors or config keys.
4. Open only relevant files or sections.
5. Expand one dependency hop at a time when current evidence is insufficient.
6. Make the smallest correct change using existing project patterns.
7. Run the narrowest meaningful check first.
8. Expand tests only when risk, project policy or failed evidence requires it.
9. Stop when the requested behavior is complete and required verification passes.

Avoid reading `node_modules/`, `vendor/`, generated outputs, complete lockfiles,
large logs or Git history unless they are relevant to the task.

Do not reread unchanged files already understood. Do not rerun successful checks
unless code affecting them changed.

## Coordination

This skill is an efficiency layer, not a replacement for specialist skills.

When `sabas-secure-qa` is active or applicable, its risk classification and
mandatory gates take priority. Apply efficiency only by avoiding duplicate
reads, duplicate scans and irrelevant operations.

When another specialist skill applies, let it define domain requirements while
this skill minimizes redundant context and tooling.

## Output

Keep progress updates concise. At completion normally report only:

- what changed;
- files/components affected;
- checks actually executed and their result;
- unresolved risks or items not verified.

Do not paste large source files or provide long tutorials unless requested.

## Stop condition

Stop exploring when the requested task is solved, the affected scope is
understood, required checks pass, applicable project/security gates are
satisfied, and no unresolved evidence justifies broader inspection.
