# AutoResearch at the commit that `vibe ws build` passes from workspace.conf.
FROM node:22-bookworm@sha256:e13726ca604184d7a91fcacab1fc09eefd642dc28e79ac34e85540dd93b78cfb
ARG COMMIT
ARG BUN_VERSION=1.3.13
ARG CLAUDE_VERSION=2.1.325
ARG PIP_CUTOFF=2026-11-15
# IS_SANDBOX: claude refuses --dangerously-skip-permissions as root without it.
ENV IS_SANDBOX=1 UV_PYTHON_INSTALL_DIR=/opt/python PATH=/opt/venv/bin:$PATH
COPY --from=ghcr.io/astral-sh/uv:0.9@sha256:538e0b39736e7feae937a65983e49d2ab75e1559d35041f9878b7b7e51de91e4 /uv /usr/local/bin/uv
RUN apt-get update \
 && apt-get install -y --no-install-recommends git rsync procps \
 && rm -rf /var/lib/apt/lists/*
RUN npm install -g "@anthropic-ai/claude-code@${CLAUDE_VERSION}" "bun@${BUN_VERSION}"
RUN git clone https://github.com/EvoMap/AutoResearch /opt/autoresearch \
 && git -C /opt/autoresearch checkout "$COMMIT"
WORKDIR /opt/autoresearch
# requirements.txt has open ranges: PIP_CUTOFF fixes them to what PyPI held on that date.
RUN uv venv --python 3.12 /opt/venv \
 && uv pip install --python /opt/venv/bin/python --exclude-newer "$PIP_CUTOFF" -r requirements.txt
RUN cd ar-runtime && bun install --frozen-lockfile
# Unpinned: apt packages and the ralph-loop plugin come as they are at build time.
RUN (claude plugin marketplace add anthropics/claude-plugins-official || true) \
 && claude plugin install ralph-loop@claude-plugins-official
