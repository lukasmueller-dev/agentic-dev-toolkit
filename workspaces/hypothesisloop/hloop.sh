# shellcheck shell=bash
# Sourced by start, stop and status: the checkout, its ports and its compose call.

# The place passes stdout and the exit code only: stderr of make and compose joins stdout.
exec 2>&1

hl_die() {
  echo "error — $*"
  exit 1
}

hl_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
hl_env_file="$HOME/.config/vibe/workspaces/hypothesisloop.env"
[[ -r "$hl_env_file" ]] || hl_die "no $hl_env_file: write HLOOP_REPO=<your checkout> in it"
HLOOP_REPO="$(sed -n 's/^HLOOP_REPO=//p' "$hl_env_file" | tail -n 1)"
[[ -n "$HLOOP_REPO" ]] || hl_die "$hl_env_file does not set HLOOP_REPO"
hl_compose_file="$HLOOP_REPO/localdev/controlplane/docker-compose.yml"
[[ -f "$hl_compose_file" ]] || hl_die "no $hl_compose_file: HLOOP_REPO names no HypothesisLoop checkout"

# The ports as localdev/lib/env.sh reads them from the committed settings.
hl_settings="$HLOOP_REPO/controlplane/settings/hypothesisloop.yaml"
HL_API_PORT="$(sed -n 's/^  api_port: *\([^ #]*\).*$/\1/p' "$hl_settings" 2>/dev/null || true)"
HL_METRICS_PORT="$(sed -n 's/^  metric_controller_port: *\([^ #]*\).*$/\1/p' "$hl_settings" 2>/dev/null || true)"
[[ -n "$HL_API_PORT" && -n "$HL_METRICS_PORT" ]] || hl_die "$hl_settings names no api_port or metric_controller_port"
# The health check make controlplane-up waits on.
# shellcheck disable=SC2034  # start and status read it
HL_HEALTH="http://127.0.0.1:$HL_API_PORT/health"

# hl_key KEY: KEY as the checkout's .env sets it, read the way the tool reads it (lib_env_value).
# set +e: a .env whose last command fails still yields its keys.
hl_key() {
  # shellcheck disable=SC1091  # the user's file, only there at runtime
  (
    set +eu
    . "$HLOOP_REPO/.env"
    printf '%s' "${!1:-}"
  )
}

# The name of the two service images, local only: compose runs them from this host, and nothing pulls them.
HL_REGISTRY=localhost:5000

# hl_compose ARG...: docker compose on the checkout's file and the tailnet override, with the
# caller's TAG and HLOOP_BIND.
hl_compose() {
  local bind="$HLOOP_BIND" google="$HOME/.config/gcloud/application_default_credentials.json"
  # The Google identity mints tokens for the gcp registry only; else, as for a missing file, /dev/null.
  [[ "$(hl_key CONTAINER_REGISTRY_PROVIDER 2>/dev/null)" == gcp && -f "$google" ]] || google=/dev/null
  # 5001: HL_IMAGE_REGISTRY_PORT of localdev/lib/env.sh, which the compose file needs set.
  TAG="$TAG" REGISTRY="$HL_REGISTRY" HLOOP_BIND="$bind" REGISTRY_PUBLISH_IP="$bind" \
    HL_API_PORT="$HL_API_PORT" HL_METRICS_PORT="$HL_METRICS_PORT" HL_IMAGE_REGISTRY_PORT=5001 \
    HL_GOOGLE_CREDENTIALS_FILE="$google" \
    docker compose -f "$hl_compose_file" -f "$hl_dir/compose.tailnet.yml" "$@"
}
