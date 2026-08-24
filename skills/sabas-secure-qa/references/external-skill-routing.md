# External defensive skill routing

Preferred upstream for the optional profiles is `mukul975/Anthropic-Cybersecurity-Skills`, pinned by the V0.5.4 installer to commit `f76261573a539ec40c3d434ecbb9e657d26aa921`.

Use only skills actually installed in the current Codex session.

## Core/web

| Risk | Preferred skill |
|---|---|
| DevSecOps scanning strategy | `implementing-devsecops-security-scanning` |
| Secret scanning | `implementing-secret-scanning-with-gitleaks` |
| Custom static rules | `implementing-semgrep-for-custom-sast-rules` |
| Runtime web DAST | `integrating-dast-with-owasp-zap-in-pipeline` |
| Broken access control | `testing-for-broken-access-control` |
| Business logic | `testing-for-business-logic-vulnerabilities` |
| XSS | `testing-for-xss-vulnerabilities` |
| Sensitive-data exposure | `testing-for-sensitive-data-exposure` |
| Dependency confusion | `detecting-dependency-confusion` |
| GitHub Actions hardening | `securing-github-actions-workflows` |

## API add-on

| Risk | Preferred skill |
|---|---|
| API broad assessment | `testing-api-security-with-owasp-top-10` |
| BOLA/IDOR | `testing-api-for-broken-object-level-authorization` |
| Mass assignment | `testing-api-for-mass-assignment-vulnerability` |
| CORS | `testing-cors-misconfiguration` |
| JWT | `testing-jwt-token-security` |

## DevSecOps add-on

| Risk | Preferred skill |
|---|---|
| CI SAST | `integrating-sast-into-github-actions-pipeline` |
| CI secret scanning | `implementing-secrets-scanning-in-ci-cd` |
| Infrastructure-as-code | `implementing-infrastructure-as-code-security-scanning` |
| Container image | `scanning-docker-images-with-trivy` |
| SBOM/supply chain | `analyzing-sbom-for-supply-chain-vulnerabilities` |

## Excluded by default

Do not automatically invoke skills aimed at:

- exploitation;
- bypass/evasion;
- credential access/cracking;
- persistence;
- command-and-control;
- malware deployment;
- post-exploitation;
- destructive denial-of-service.

A defensive test may use a minimal non-destructive reproduction in an authorized environment when needed to confirm a finding, but the goal is validation and remediation rather than building an exploitation chain.
