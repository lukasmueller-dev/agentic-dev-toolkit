# AutoResearch at one pinned commit; the image tag is that commit.
FROM node:22-bookworm@sha256:e13726ca604184d7a91fcacab1fc09eefd642dc28e79ac34e85540dd93b78cfb
ARG COMMIT=21f591298aca78690722686c38984ac2b7d6f7e6
ARG BUN_VERSION=1.3.13
ARG CLAUDE_VERSION=2.1.325
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
RUN uv venv --python 3.12 /opt/venv \
 && uv pip install --python /opt/venv/bin/python -r requirements.txt
RUN cd ar-runtime && bun install --frozen-lockfile
# Unpinned: the ralph-loop plugin comes from the marketplace as it is at build time.
RUN (claude plugin marketplace add anthropics/claude-plugins-official || true) \
 && claude plugin install ralph-loop@claude-plugins-official
