---
name: sabas-efficient-development
description: Minimize unnecessary token, context and tool usage while developing, debugging, reviewing or maintaining an existing codebase. Use when a coding task should be solved with the smallest reliable working set: search before reading, reuse known context, make focused changes, run targeted verification first and expand scope only when evidence requires it. Never use this skill to bypass required security, correctness or project-specific checks.
license: MIT
compatibility: Agent Skills open standard; designed for ChatGPT Skills, OpenAI Codex and Hermes Agent. Works best when the agent can search repository files and run targeted tests.
metadata:
  author: Sabas + OpenAI
  version: "0.1.0"
  category: efficient-development
---

# Sabas Efficient Development

## Mission

Solve the requested development task with the smallest reliable amount of context, file reading, tool usage and repeated work.

Optimize waste, not quality.

A correct solution with necessary verification is more important than saving tokens. Efficiency must come from better scoping, targeted searches, reuse of evidence and early stopping.

## Non-negotiable rules

1. Obey active project instructions and higher-priority safety/security requirements.
2. Never skip a required test, security gate, migration check or validation merely to reduce token usage.
3. Do not broaden the task into unrelated refactors, cleanup or architecture work unless required for correctness.
4. Do not reread unchanged information already available in the current session.
5. Do not claim that a check passed unless it was actually executed or directly verified.
6. Do not expose private chain-of-thought. Keep internal reasoning concise and return conclusions, evidence and actions.

## 1. Classify the working mode

Choose the lightest mode that can reliably solve the task.

### ECO

Use for local and well-bounded work such as:

- a known bug in one component;
- a small UI/CSS/JS adjustment;
- a localized PHP/Python change;
- a focused test failure;
- a small SQL/query correction.

Start from the named file, symbol, error or diff. Do not map the whole repository.

### STANDARD

Use when the affected area is not fully known, several components interact, or a normal feature touches multiple files.

Search first, identify the dependency path, then build a focused working set.

### DEEP

Use only when evidence justifies broader analysis, for example:

- architecture or cross-cutting changes;
- systemic or intermittent bugs with unclear origin;
- migrations affecting many modules;
- release validation;
- security-sensitive work requiring broader review.

Do not select DEEP merely because the repository is large.

## 2. Start from evidence already available

Before using tools, reuse:

- files already inspected in the current task;
- error messages already supplied;
- known project architecture;
- current diff information;
- decisions already made by the user;
- previous successful test results that remain valid for unchanged code.

Do not ask for or fetch information that is already present and sufficient.

## 3. Search before reading

When repository access is available:

1. Inspect the current change state first when relevant: status, diff summary and changed filenames.
2. Search for exact filenames, symbols, routes, selectors, SQL tables, error strings or configuration keys.
3. Open only the relevant files or sections returned by the search.
4. Expand one dependency hop at a time only when the current evidence is insufficient.

Prefer symbol/text search to recursive reading.

Avoid reading by default:

- `node_modules/`, `vendor/`, build outputs, coverage outputs and generated files;
- complete lockfiles unless dependency state is relevant;
- large logs when a focused search or recent tail is sufficient;
- Git history unless regression origin or authorship is relevant;
- entire large files when a relevant range or symbol can be inspected.

## 4. Maintain a small working set

Treat the files required to understand and change the task as the active working set.

For a local task, aim to begin with only a few files. For a multi-component task, expand deliberately.

Before opening another file, ask whether it can materially change the implementation or verification decision. If not, do not load it.

If a file was already read and has not changed, use the existing understanding instead of reopening it.

## 5. Make the smallest correct change

Prefer:

- localized patches;
- existing project patterns;
- existing helpers and dependencies;
- changes that preserve public behavior outside the requested scope.

Avoid:

- rewriting full files for a small edit;
- speculative abstractions;
- unrelated formatting churn;
- dependency additions when the project already has an adequate solution;
- opportunistic refactors that make review and verification larger.

If a broader refactor becomes necessary, state the reason briefly and expand scope deliberately.

## 6. Verify progressively

Use a verification ladder.

1. Run the narrowest syntax, lint, type or unit check that directly covers the change.
2. Fix failures before running broader checks.
3. Run the affected integration or feature tests when relevant.
4. Run the full suite only when the change is cross-cutting, release-oriented, project policy requires it, or targeted checks cannot provide sufficient confidence.

Do not rerun a successful check unless code affecting that check changed.

Do not repeatedly execute expensive scans while still making small edits.

## 7. Coordinate with other skills

This skill is an efficiency layer, not a replacement for specialist skills.

When `sabas-secure-qa` is active or applicable:

- follow its risk classification and mandatory gates;
- never downgrade FAST/STANDARD/DEEP/RELEASE security coverage to save tokens;
- apply this skill inside the selected security mode by avoiding duplicate scans, duplicate reads and irrelevant tools.

When another specialist skill is active, let that skill define domain requirements while this skill minimizes redundant context and operations.

## 8. Use tools economically

When tools support batching, combine independent searches or reads that are already known to be necessary.

Prefer deterministic local evidence over speculative exploration.

Do not browse the web for stable project facts already available in the repository.

Do browse or retrieve external documentation when current versions, APIs, standards or behavior can materially affect correctness.

Stop tool use when the implementation decision is supported and the required verification is complete.

## 9. Keep responses compact

During work:

- report only material discoveries, blockers or scope changes;
- do not narrate every command;
- do not repeat the task description;
- do not paste large source files already present in the repository.

At completion, normally report only:

- what changed;
- files/components affected;
- checks actually executed and their result;
- unresolved risks or items not verified.

Provide long explanations, full-file output or tutorials only when the user asks for them or they are necessary to use the result.

## 10. Manage long sessions

After a completed milestone, avoid carrying obsolete exploratory detail into an unrelated next task.

When the platform supports context compaction or a fresh task/session, use or recommend it only at clean boundaries after preserving the essential state: decisions, changed files, pending work and verification status.

Do not compact in the middle of an unresolved debugging chain if doing so would discard useful evidence.

## Stop condition

Stop exploring when all of the following are true:

- the requested behavior is implemented or the question is answered;
- the affected scope is understood well enough;
- required targeted checks pass;
- applicable security/project gates are satisfied;
- no unresolved evidence indicates that broader inspection is necessary.

Do not continue searching merely because more repository content exists.
