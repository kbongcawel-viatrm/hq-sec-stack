#!/usr/bin/env sh
set -eu

COMPOSE_FILE="${COMPOSE_FILE:-security-stack.compose.yml}"
PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
PROFILES="${SECSTACK_PROFILES:-all}"
TIMEOUT_SECONDS="${KILLSWITCH_TIMEOUT_SECONDS:-60}"
MODE="${1:-stop}"

log() {
  printf '%s %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"
}

compose() {
  docker compose -f "${COMPOSE_FILE}" "$@"
}

profile_args() {
  for profile in ${PROFILES}; do
    printf -- '--profile\n%s\n' "${profile}"
  done
}

usage() {
  cat <<'USAGE'
usage: scripts/killswitch.sh [stop|down|pause]

Modes:
  stop   Gracefully stop containers and preserve networks, volumes, backups, and reports. Default.
  down   Stop and remove containers/networks, preserving named volumes.
  pause  Pause running containers without stopping processes.

Environment:
  SECSTACK_PROFILES="all"             Profiles to target.
  KILLSWITCH_TIMEOUT_SECONDS="60"     Graceful stop timeout.
  COMPOSE_FILE="security-stack.compose.yml"
USAGE
}

main() {
  if [ "${MODE}" = "-h" ] || [ "${MODE}" = "--help" ]; then
    usage
    exit 0
  fi

  if ! command -v docker >/dev/null 2>&1; then
    echo "Missing required command: docker" >&2
    exit 127
  fi

  cd "${PROJECT_ROOT}"
  log "killswitch mode=${MODE} profiles=${PROFILES}"

  case "${MODE}" in
    stop)
      compose $(profile_args) stop -t "${TIMEOUT_SECONDS}"
      ;;
    down)
      compose $(profile_args) down --remove-orphans --timeout "${TIMEOUT_SECONDS}"
      ;;
    pause)
      compose $(profile_args) pause || true
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac

  compose $(profile_args) ps || true
  log "killswitch complete; named volumes were not removed"
}

main "$@"
