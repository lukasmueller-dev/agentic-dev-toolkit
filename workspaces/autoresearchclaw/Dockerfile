# AutoResearchClaw at one pinned commit. Tag the image with the commit.
FROM node:22-bookworm-slim
ARG COMMIT=be4ba4755bf1b52220f25e13b2293b5956590070
ENV PIP_NO_CACHE_DIR=1 PATH=/opt/venv/bin:$PATH
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates git jq python3 python3-venv \
 && rm -rf /var/lib/apt/lists/*
RUN git init -q /opt/arc \
 && git -C /opt/arc fetch -q --depth 1 https://github.com/aiming-lab/AutoResearchClaw.git "$COMMIT" \
 && git -C /opt/arc checkout -q FETCH_HEAD
RUN python3 -m venv /opt/venv \
 && pip install -e "/opt/arc[anthropic,pdf]" torch scikit-learn scipy matplotlib gymnasium
RUN npm install -g acpx @agentclientprotocol/claude-agent-acp
