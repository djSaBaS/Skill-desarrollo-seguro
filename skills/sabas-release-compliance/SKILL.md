---
name: sabas-release-compliance
description: >-
  Evidence-based prelaunch checklist for web applications, mobile apps, APIs and
  SaaS products. Use when preparing a public release, app-store submission,
  production launch, privacy/legal readiness review or launch approval. Evaluate
  35 contextual legal, privacy, security, quality and distribution controls,
  distinguishing mandatory requirements from recommendations and unverified items.
  Do not trigger on ordinary coding fixes or treat this as a substitute for legal advice.
license: MIT
compatibility: >-
  Agent Skills standard; works with OpenAI Codex, Hermes Agent and
  Google Antigravity IDE. Legal conclusions require jurisdiction-specific review.
metadata:
  author: Sabas + OpenAI
  version: "0.1.0"
  category: release-compliance
---

# Sabas Release Compliance

## Mission

Decide whether an app or service is ready for release, with traceable evidence and
no invented legal guarantees. The 35 controls in
`references/preflight-35.md` are an original, independent checklist inspired
by a public Instagram reel mentioning 35 checks. The author's downloadable
guide was not available during authoring; **do not present this checklist as
the reel's exact 35 points**.

## Activation and boundaries

- Activate for an explicit release, app-store submission, go-live, legal/privacy
  review or launch decision. Do not run all 35 checks for normal edits.
- Ask for or infer, with uncertainty marked: jurisdiction and target countries,
  web/mobile/API distribution, B2B/B2C, audience and minors, personal-data
  categories, tracking/ads, payments, artificial intelligence, regulated domain,
  and deployment environment.
- A missing fact produces `NOT_VERIFIED`, not an invented `PASS`.
- For security code and test evidence, route narrowly to `sabas-secure-qa`
  if installed; do not duplicate its scans or bypass its blocking verdict.
- Apply `sabas-efficient-development` to avoid rechecking unaffected controls.
- If `usuario-torpe-qa` is installed, use it only in an authorized controlled
  environment and only where UI misuse checks are relevant.

## Procedure

1. Identify the product, release version, audience, countries, platform and
   deployment plan. Record unknown inputs.
2. Read `references/preflight-35.md` and select applicability per control.
3. For each applicable control gather a concrete file, URL, screenshot, test
   output, registry document, store-console evidence or named owner.
4. Assign exactly one state: `PASS`, `FAIL`, `NOT_VERIFIED` or
   `NOT_APPLICABLE`. Explain why; never mark omitted controls as passed.
5. Classify `FAIL` and `NOT_VERIFIED` as `BLOCKER` or `ADVISORY`
   according to the demonstrated legal, security, store or release risk.
   A possible legal obligation without enough context is `REVIEW_REQUIRED`,
   not automatically a proven violation.
6. Create a short remediation plan, with evidence required to close each gap.
7. Report the release decision as `READY`, `READY_WITH_WARNINGS`,
   `BLOCKED` or `INSUFFICIENT_EVIDENCE`. Never present it as legal
   certification or absolute security.

## Output

Provide a concise release summary, jurisdiction/platform assumptions, table
`ID | Applicable | State | Evidence | Severity | Owner/next action`,
top blockers, test commands actually executed, and a dated go/no-go decision.
Separate **verified facts**, **open questions** and **legal review needed**.
Do not create a fake legal opinion, consent record, DPIA or store approval.

## Legal research policy

Use official, current jurisdiction-specific sources when a legal requirement
matters. For Spain/EU, start from AEPD, BOE and EUR-Lex; for mobile stores,
use the current Apple/Google developer policies. The GDPR, Spain's LSSI,
consumer law, accessibility obligations and EU AI Act have different scopes
and exceptions. A dated source is not proof of applicability to a product.
Escalate disputed interpretations, regulated sectors and high-risk assessments
to a qualified professional.

## Source starting points

- AEPD: https://www.aepd.es/derechos-y-deberes/cumple-tus-deberes/medidas-de-cumplimiento/proteccion-de-datos-desde-el-diseno
- Spanish LSSI: https://www.boe.es/buscar/act.php?id=BOE-A-2002-13758
- GDPR: https://eur-lex.europa.eu/eli/reg/2016/679/oj
- EU AI Act (consolidated): https://eur-lex.europa.eu/eli/reg/2024/1689/2026-07-27/eng
- Google Play user data: https://support.google.com/googleplay/android-developer/answer/10144311
- Apple App Review: https://developer.apple.com/app-store/review/guidelines/
