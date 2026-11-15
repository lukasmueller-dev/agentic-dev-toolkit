# Kapso at one pinned commit. No secret and no user code inside.
FROM node:22-bookworm-slim
# Must equal `commit` in workspace.conf (tests/ws-kapso.bats checks it).
ARG COMMIT=8b897c7330fdf02bc9080e492a768b70b18fbf0d
# Kapso commits with no identity of its own, so git needs one. Claude Code 2.1.310 is what Kapso's CI installs at that commit.
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates git jq python3 python3-pip python3-venv \
 && rm -rf /var/lib/apt/lists/* \
 && git config --system user.name kapso \
 && git config --system user.email kapso@localhost \
 && npm install -g @anthropic-ai/claude-code@2.1.310 \
 && python3 -m venv /opt/kapso \
 && /opt/kapso/bin/pip install --no-cache-dir "git+https://github.com/Leeroo-AI/kapso@${COMMIT}"
ENV PATH=/opt/kapso/bin:$PATH
# Claude Code refuses --dangerously-skip-permissions as root; `node` is uid 1000.
USER node
