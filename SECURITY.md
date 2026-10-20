# Security policy

Do not report vulnerabilities in a public issue. Use the repository owner's
private security contact or GitHub private vulnerability reporting.

This starter provides sensible container defaults, but it is not a managed
platform. Operators remain responsible for host patching, firewall rules,
access control, dependency updates, off-site backups and monitoring.

Never commit actual env files (`app/backend/.env`, `app/frontend/.env`,
`infra/.env`, `infra/.env.production`),
`secrets/` or `backups/`. If a secret
is exposed, remove it from current configuration, rotate it at the service,
and only then clean repository history if necessary.
