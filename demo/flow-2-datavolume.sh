#!/usr/bin/env bash
# Flow 2: CDI imports a cloud image into a PVC, then a persistent Fedora VM boots from it.
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(cd "$(dirname "$0")/.." && pwd)/scripts/lib.sh"
VM=fedora

banner "Flow 2 - DataVolume import + persistent VM (${DEMO_NS}/${VM})"
vm_exists "${VM}" || die "VM ${VM} not synced yet - check ./scripts/status.sh"

log "Starting ${VM}. WaitForFirstConsumer: the import only begins once the VM pod is scheduled."
vctl -n "${DEMO_NS}" start "${VM}" 2>/dev/null || ok "already running"

log "Import progress (DataVolume name / phase / progress):"
start=$(date +%s)
until jsonpath_is Succeeded -n "${DEMO_NS}" get dv fedora-root -o 'jsonpath={.status.phase}'; do
  k -n "${DEMO_NS}" get dv -o json | jq -r -f "${JQ_DIR}/dv-progress.jq" | sed 's/^/  /'
  [ $(( $(date +%s) - start )) -lt 900 ] || die "import still not done after 15m"
  sleep 10
done
ok "DataVolume fedora-root Succeeded ($(( $(date +%s) - start ))s)"
k -n "${DEMO_NS}" get pvc fedora-root
pause

wait_until 600 "VMI ${VM} Ready" vmi_ready "${VM}"
k get vmi -n "${DEMO_NS}" -o json | jq -r -f "${JQ_DIR}/vmi-summary.jq" | column -t
echo
echo "  Console:  virtctl --context ${KCTX} -n ${DEMO_NS} console ${VM}   (fedora / kubevirt)"
echo "  Persistence test: write a file, then 'virtctl stop/start ${VM}' - it survives (PVC), unlike cirros."
