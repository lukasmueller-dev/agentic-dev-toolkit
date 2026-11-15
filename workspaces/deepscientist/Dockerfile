# DeepScientist 1.6.0 at one commit. Tag the image with that commit (workspace.conf).
FROM node:22-bookworm-slim

ARG COMMIT=b36624417f0c6b8238ec02db37b94d6db2faa5b0

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git jq python3 python3-venv \
 && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/ResearAI/DeepScientist /opt/ds \
 && git -C /opt/ds checkout "$COMMIT" \
 && cd /opt/ds \
 && npm ci && npm --prefix src/ui ci && npm --prefix src/tui ci \
 && npm run ui:build && npm run tui:build \
 && ln -s /opt/ds/bin/ds.js /usr/local/bin/ds

# claude comes from the repo's own npm install; IS_SANDBOX lets it run as root with all permissions.
ENV PATH=/opt/ds/node_modules/.bin:$PATH IS_SANDBOX=1

# First launch at build: uv and the Python env land in /ws/data/runtime.
# A start mounts /ws/data over that, so the result moves to /opt/ds-seed; `start` copies it back once.
RUN mkdir -p /ws/data \
 && ds --home /ws/data init \
 && rm -f /ws/data/runtime/daemon.json \
 && mv /ws/data /opt/ds-seed

CMD ["sleep", "infinity"]
