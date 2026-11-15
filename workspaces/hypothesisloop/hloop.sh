# shellcheck shell=bash
# Sourced by start, stop and status: the checkout, its ports and its compose call.

# Stdout, not stderr: the place passes stdout and the exit code only.
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

# hl_key KEY: KEY as the checkout's .env sets it, read the way the tool reads it (lib_env_value).
hl_key() {
  # shellcheck disable=SC1091  # the user's file, only there at runtime
  (set +u && . "$HLOOP_REPO/.env" && printf '%s' "${!1:-}")
}

# hl_compose ARG...: docker compose on the checkout's file, with the values its make targets pass.
hl_compose() {
  local tag address bind google="$HOME/.config/gcloud/application_default_credentials.json"
  tag="$(cat "$HLOOP_REPO/localdev/.image-tag" 2>/dev/null || true)"
  address="$(cat "$HLOOP_REPO/localdev/.host-address" 2>/dev/null || true)"
  bind="$(hl_key LOCAL_REACHABLE_ADDRESS)"
  [[ -n "$tag" ]] || hl_die "no $HLOOP_REPO/localdev/.image-tag: run make local-images there"
  [[ -n "$address" ]] || hl_die "no $HLOOP_REPO/localdev/.host-address: run make render-settings there"
  [[ -n "$bind" ]] || hl_die "$HLOOP_REPO/.env does not set LOCAL_REACHABLE_ADDRESS, the tailnet address the stack binds to"
  # A bind mount of a missing file fails; localdev/lib/auth.sh mounts /dev/null then.
  [[ -f "$google" ]] || google=/dev/null
  # 5001: HL_IMAGE_REGISTRY_PORT of localdev/lib/env.sh, which the compose file needs set.
  TAG="$tag" REGISTRY="$address:5000" REGISTRY_PUBLISH_IP="$bind" HLOOP_BIND="$bind" \
    HL_API_PORT="$HL_API_PORT" HL_METRICS_PORT="$HL_METRICS_PORT" HL_IMAGE_REGISTRY_PORT=5001 \
    HL_GOOGLE_CREDENTIALS_FILE="$google" \
    docker compose -f "$hl_compose_file" -f "$hl_dir/compose.tailnet.yml" "$@"
}
