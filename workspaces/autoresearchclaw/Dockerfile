# AutoResearchClaw at one pinned commit. Tag the image with the commit.
# Every input is pinned: base by digest, npm and pip packages by version.
FROM node:22-bookworm-slim@sha256:e9f565d32859f0cbfb52125eafe8be39390f24dac302dc3cdf566e8ba3ab21ee
ARG COMMIT=be4ba4755bf1b52220f25e13b2293b5956590070
ENV PIP_NO_CACHE_DIR=1 PATH=/opt/venv/bin:$PATH
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates git jq python3 python3-venv \
 && rm -rf /var/lib/apt/lists/*
RUN git init -q /opt/arc \
 && git -C /opt/arc fetch -q --depth 1 https://github.com/aiming-lab/AutoResearchClaw.git "$COMMIT" \
 && git -C /opt/arc checkout -q FETCH_HEAD
RUN python3 -m venv /opt/venv \
 && pip install -e "/opt/arc[anthropic,pdf]" torch==2.15.0 scikit-learn==1.9.1 scipy==1.17.1 matplotlib==3.11.2 gymnasium==1.4.0
RUN npm install -g acpx@0.22.0 @agentclientprotocol/claude-agent-acp@0.107.0 @anthropic-ai/claude-code@2.1.325
