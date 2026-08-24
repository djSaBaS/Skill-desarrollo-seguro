> Fuente de verdad machine-readable: `EXTERNAL-SKILLS.lock.json`. No cambies el commit o las listas solo en el script; actualiza el lockfile y vuelve a validar el bundle.

# External security skill profiles

V0.4 intentionally uses a small allowlist rather than installing all 817 upstream skills.

El instalador principal de V0.4 recomienda `-ExternalProfile all`, que combina solo estas 20 skills defensivas; el instalador externo usado por separado conserva `web` como default mínimo.

Pinned upstream commit:

`f76261573a539ec40c3d434ecbb9e657d26aa921`

## web (default del instalador externo standalone, 10)

- implementing-devsecops-security-scanning
- implementing-secret-scanning-with-gitleaks
- implementing-semgrep-for-custom-sast-rules
- integrating-dast-with-owasp-zap-in-pipeline
- testing-for-broken-access-control
- testing-for-business-logic-vulnerabilities
- testing-for-xss-vulnerabilities
- testing-for-sensitive-data-exposure
- detecting-dependency-confusion
- securing-github-actions-workflows

## api add-on (5)

- testing-api-security-with-owasp-top-10
- testing-api-for-broken-object-level-authorization
- testing-api-for-mass-assignment-vulnerability
- testing-cors-misconfiguration
- testing-jwt-token-security

## devsecops add-on (5)

- integrating-sast-into-github-actions-pipeline
- implementing-secrets-scanning-in-ci-cd
- implementing-infrastructure-as-code-security-scanning
- scanning-docker-images-with-trivy
- analyzing-sbom-for-supply-chain-vulnerabilities

The installer checks that every expected `SKILL.md` exists at the pinned commit before copying it.
