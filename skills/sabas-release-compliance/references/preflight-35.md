# 35-point prelaunch review (original checklist)

**Origin and verification:** The public caption of the reel by @bybrayan.ai
(11 November 2026, https://www.instagram.com/reel/DfnhGOihSMs/)
mentions 35 legal and technical checks but does not enumerate them. The
following 35 checks are an original, verifiable proposal, **not a
transcription of the creator's separate guide**.

## Applicability and evidence

For each item give `PASS`, `FAIL`, `NOT_VERIFIED` or `NOT_APPLICABLE`.
Record the jurisdiction, applicable product features, an evidence pointer and
a responsible person. Never interpret `NOT_APPLICABLE` as `PASS`.
Treat a potentially applicable law as `REVIEW_REQUIRED` if its scope is
uncertain. Do not assert that all 35 items are universally legally mandatory.

### 1. Product and legal scope

01. **Product inventory:** list deployable services, API endpoints, apps,
    third-party SDKs and public channels; evidence: versioned architecture.
02. **Publication footprint:** identify target countries, languages, legal
    entities, consumer/business audience and app-store distribution.
03. **Accountability:** identify operator/controller, publication approver,
    support contact and responsible maintenance owner.
04. **Audience and age:** determine whether minors are involved and what
    account, moderation, data and age-assurance safeguards are applicable.
05. **Regulatory classification:** determine whether the product operates in
    health, education, employment, finance, biometrics or other regulated
    contexts; record expert review where necessary.

### 2. Personal data and transparency

06. **Data map:** inventory all personal data, purposes, flows, processors,
    storage locations and retention periods, including telemetry.
07. **Lawful basis:** identify and evidence the applicable GDPR basis for each
    purpose; do not equate acceptance of terms with valid consent.
08. **Privacy disclosures:** check the privacy notice is accessible, accurate,
    understandable, versioned and covers required information and recipients.
09. **Retention and deletion:** document retention schedules, actual purge
    mechanisms, backups and user/account deletion when required.
10. **Data-subject rights:** verify the intake, identity verification, response,
    correction, export and objection/erasure workflows as applicable.

### 3. Tracking, processors and privacy engineering

11. **Cookies and SDK tracking:** inventory analytics, pixels, device IDs and
    advertising identifiers; validate permission/consent rules where required.
12. **Third-party sharing:** check recipients, processor contracts, SDK
    disclosures and the product's actual data flows align.
13. **International transfers:** identify cross-border transfers and assess
    relevant safeguards and legal transfer mechanisms.
14. **Privacy by design/default:** minimize data, privileges, collection and
    visibility; test default settings against documented purposes.
15. **Impact assessment:** assess whether a DPIA, DPO or consultation is
    needed; document the decision and review with an expert if uncertain.

### 4. Security and integrity

16. **Authentication and sessions:** verify MFA where warranted, server-side
    inactivity and absolute session expiration, logout/revocation, secure
    cookies, refresh-token lifecycle and account recovery protections.
17. **Authorization and abuse:** test IP + identity rate limits, trusted
    proxies and 429 behavior; verify per-user/per-tenant row isolation on
    read/write/export operations, roles and risky input/file paths.
18. **Secrets and transport:** require private, untracked server-side
    `.env` for real credentials and production keys outside the document
    root; verify exposure prevention, access permissions, safe provisioning,
    rotation, suitable TLS and appropriate encryption at rest.
19. **Supply chain:** audit vulnerable dependencies, SDK provenance,
    licenses, build provenance and SBOM when appropriate.
20. **Logging and incident readiness:** ensure redacted logs, alerts,
    incident contacts, breach handling and rollback evidence exist.

### 5. Quality and reliable deployment

21. **Functional regression:** execute unit, integration and E2E tests for
    affected critical user journeys; preserve actual CI evidence.
22. **Device/platform testing:** validate target OS/browser versions, offline
    behavior and permissions; record compatibility limitations.
23. **Performance and resilience:** test critical latency, load, timeouts,
    retry boundaries and degraded network behavior at relevant scale.
24. **Backup and rollback:** rehearse restore/migration rollback, confirm
    recovery targets and avoid changing production without authorization.
25. **Release integrity:** validate reproducible/versioned artifacts, signing
    and protected release pipelines, deployment checklist and change log.

### 6. Distribution, commerce and intellectual property

26. **Service-provider information:** assess Spanish LSSI or corresponding
    local requirements for operator information, contact and legal notice.
27. **Terms and transactions:** check contractual terms, pricing, renewals,
    cancellations, refunds, tax/invoicing and consumer information when sold.
28. **Rights and licensing:** confirm entitlement for code, fonts, images,
    music, datasets, trademarks and embedded third-party content.
29. **Marketing and messaging:** review opt-in/opt-out and notices for
    promotional email, push, profiling and paid advertising as applicable.
30. **App-store disclosures:** verify Google Play Data Safety, Apple privacy
    fields, policies, screenshots, permissions and account deletion rules for
    the actual stores selected.

### 7. Accessibility, AI and final decision

31. **Accessibility:** test accessible navigation, contrast, assistive tech
    and whether applicable EU/national accessibility laws cover the service.
32. **AI disclosures:** identify automated interactions and synthetic media;
    assess applicable EU AI Act transparency duties and product notices.
33. **AI risk classification:** evaluate prohibited and high-risk AI use
    cases, applicable dates and governance requirements; do not assume all
    AI apps are high-risk.
34. **Special-sector controls:** assess specific obligations for children,
    health, education, payments or geolocation that the core checklist does
    not fully capture.
35. **Go/no-go evidence:** confirm named approval, open blocker register,
    monitoring, support plan, rollback owner and dated release decision.

## Release policy

- **BLOCKED:** a verified critical flaw or clear unmet prerequisite that
  makes the release unsafe or unauthorized.
- **INSUFFICIENT_EVIDENCE:** mandatory information or verification is missing
  and no defensible release determination is possible.
- **READY_WITH_WARNINGS:** no unresolved blocker; recorded nonblocking gaps
  are accepted by an authorized owner with follow-up.
- **READY:** applicable controls verified; does not imply guaranteed legal
  compliance or absence of vulnerabilities.

This checklist is a triage tool, not legal advice or an audit certificate.
Review official policy updates as of the actual launch date.
