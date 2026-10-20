FROM ghcr.io/astral-sh/ruff:0.17.1 AS ruff
FROM mvdan/shfmt:v3.11.0 AS shfmt
FROM rhysd/actionlint:1.7.7 AS actionlint
FROM hadolint/hadolint:v2.12.0-alpine AS hadolint

FROM node:22-alpine

# Alpine maintains system tool versions; application lint tools are pinned below.
# hadolint ignore=DL3018
RUN apk add --no-cache bash python3 py3-pip shellcheck \
    && python3 -m venv /opt/tools \
    && /opt/tools/bin/pip install --no-cache-dir yamllint==1.37.1 \
    && npm install --global prettier@3.6.2 \
    && npm cache clean --force

COPY --from=ruff /ruff /usr/local/bin/ruff
COPY --from=shfmt /bin/shfmt /usr/local/bin/shfmt
COPY --from=actionlint /usr/local/bin/actionlint /usr/local/bin/actionlint
COPY --from=hadolint /bin/hadolint /usr/local/bin/hadolint

ENV PATH="/opt/tools/bin:${PATH}" \
    HOME=/tmp \
    XDG_CACHE_HOME=/tmp

WORKDIR /workspace
ENTRYPOINT ["bash", "scripts/tooling/quality.sh"]
