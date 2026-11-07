# shellcheck shell=bash
# Shared helpers. macOS ships bash 3.2 - no associative arrays / mapfile here.

# shellcheck source=scripts/env.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"
mkdir -p "${STATE_DIR}"

log()    { printf '\033[1;34m[%s]\033[0m %s\n' "$(date +%H:%M:%S)" "$*"; }
ok()     { printf '\033[1;32m  ✔\033[0m %s\n' "$*"; }
warn()   { printf '\033[1;33m  !\033[0m %s\n' "$*" >&2; }
die()    { printf '\033[1;31m  ✘ %s\033[0m\n' "$*" >&2; exit 1; }
banner() { printf '\n\033[1;35m==== %s ====\033[0m\n' "$*"; }

pause() {
  # DEMO_AUTO=1 skips interactive pauses (CI / dry runs)
  [ "${DEMO_AUTO:-0}" = "1" ] && return 0
  printf '\033[2m  ⏎ press enter to continue...\033[0m'; read -r _
}

need() { command -v "$1" >/dev/null 2>&1 || die "missing '$1' - $2"; }

k()  { kubectl --context "${KCTX}" "$@"; }
vctl() { virtctl --context "${KCTX}" "$@"; }

cluster_exists() { kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; }

gitea_api() {
  # gitea_api <METHOD> <path> [json-body]
  curl -fsS -u "${GITEA_USER}:${GITEA_PASSWORD}" -X "$1" \
    -H 'Content-Type: application/json' ${3:+-d "$3"} \
    "http://127.0.0.1:${GITEA_HOST_PORT}/api/v1$2"
}

# wait_until <timeout-seconds> <description> <command...>
wait_until() {
  local timeout="$1" desc="$2"; shift 2
  local start; start=$(date +%s)
  until "$@" >/dev/null 2>&1; do
    if [ $(( $(date +%s) - start )) -ge "${timeout}" ]; then
      die "timed out after ${timeout}s waiting for: ${desc}"
    fi
    sleep 3
  done
  ok "${desc}"
}

jsonpath_is() {
  # jsonpath_is <expected> <kubectl get args... -o jsonpath=...>
  local want="$1"; shift
  [ "$(k "$@" 2>/dev/null)" = "${want}" ]
}

kubevirt_deployed() { jsonpath_is Deployed -n kubevirt get kubevirt kubevirt -o 'jsonpath={.status.phase}'; }
cdi_deployed()      { jsonpath_is Deployed get cdi cdi -o 'jsonpath={.status.phase}'; }
vmi_ready()         { jsonpath_is True -n "${DEMO_NS}" get vmi "$1" -o 'jsonpath={.status.conditions[?(@.type=="Ready")].status}'; }
vm_exists()         { k -n "${DEMO_NS}" get vm "$1" >/dev/null 2>&1; }
