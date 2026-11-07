#!/usr/bin/env bash
# Default: delete the kind cluster + Gitea. --all also deletes the Colima VM.
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

banner "teardown"
cluster_exists && kind delete cluster --name "${CLUSTER_NAME}" && ok "kind cluster deleted"
docker rm -f "${GITEA_CONTAINER}" >/dev/null 2>&1 && ok "gitea container removed" || true
docker volume rm "${GITEA_VOLUME}" >/dev/null 2>&1 && ok "gitea volume removed" || true

if [ "${1:-}" = "--all" ]; then
  colima delete --profile "${COLIMA_PROFILE}" --force && ok "colima profile ${COLIMA_PROFILE} deleted"
else
  echo "  Colima VM kept. Stop it with: colima stop --profile ${COLIMA_PROFILE}  (or rerun with --all)"
fi
