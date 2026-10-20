# Contributing

Keep changes focused on the Flask/React template and its single-host
deployment workflow. Explain what a change solves and how it was verified.

Before opening a pull request:

```bash
make init
make format
make lint
make check
make test
make up
make smoke
```

CI checks formatting without changing files. Commit formatter changes with the
code they belong to. The quality image runs Ruff, ShellCheck, shfmt, Prettier,
yamllint, Hadolint and actionlint with the same commands used locally.

For schema changes, generate an Alembic revision, review its upgrade and
downgrade, and test it against a disposable database. Never modify a migration
that has already shipped. Test backup and restore when changing storage or
operational scripts.

Update the relevant documentation when changing commands, environment settings,
service names or HTTP endpoints. Do not commit real env files, tokens, passwords,
database dumps or private infrastructure details.
