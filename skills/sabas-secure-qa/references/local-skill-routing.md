# Local skill routing

Use the minimum useful set.

## `web-code-quality-php-mysql-js-v2`

Use when editing PHP, MySQL, JavaScript, AJAX, HTML/CSS or WordPress code. Let it govern code quality/Sonar/commenting conventions while `sabas-secure-qa` governs security completion.

## `web-security-audit`

Use for focused review of web risks such as SQL injection, XSS, CSRF, sessions, permissions, upload handling, secrets and endpoints.

Avoid running the same checklist twice. Import its findings into the common finding format and validate them.

## `web-test-validator`

Use after remediation for final regression and project-specific validation.

## `usuario-torpe-qa`

Use only when an actual UI exists and the environment is confirmed local/test/staging according to that skill's own mandatory gate.

Read its full `SKILL.md` before dynamic testing. Its rules take priority for the duration of its audit, including its rule not to modify code during the audit itself.

After it returns findings, `sabas-secure-qa` resumes control, patches in-scope issues and retests.

## Browser/Playwright skills

If a browser/Playwright skill is available and `usuario-torpe-qa` permits its use, use it for real evidence. Never replace missing browser access with a narrated pretend test.
