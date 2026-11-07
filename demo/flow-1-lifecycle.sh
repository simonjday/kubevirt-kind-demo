#!/usr/bin/env bash
# Flow 1: a VM is just a pod. Prove KVM acceleration, then pause/stop/start.
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(cd "$(dirname "$0")/.." && pwd)/scripts/lib.sh"
VM=cirros

banner "Flow 1 - VM lifecycle (${DEMO_NS}/${VM})"
vm_exists "${VM}" || die "VM ${VM} not synced yet - check ./scripts/status.sh"
wait_until 300 "VMI ${VM} Ready" vmi_ready "${VM}"
k get vmi -n "${DEMO_NS}" -o json | jq -r -f "${JQ_DIR}/vmi-summary.jq" | column -t
pause

log "The VM runs inside a virt-launcher pod - ordinary Kubernetes scheduling:"
pod="$(k -n "${DEMO_NS}" get pod -l "kubevirt.io/vm=${VM}" -o 'jsonpath={.items[0].metadata.name}')"
k -n "${DEMO_NS}" get pod "${pod}" -o wide
log "Hardware virtualisation check:"
k -n "${DEMO_NS}" get pod "${pod}" -o json | jq -r -f "${JQ_DIR}/launcher-kvm.jq"
k -n "${DEMO_NS}" exec "${pod}" -c compute -- sh -c 'ps -o args= -C qemu-kvm 2>/dev/null | grep -o "accel=[a-z]*" | head -1 || true'
pause

log "Pause (vCPUs frozen, pod stays):"
vctl -n "${DEMO_NS}" pause vm "${VM}"
wait_until 60 "VMI Paused" jsonpath_is True -n "${DEMO_NS}" get vmi "${VM}" -o 'jsonpath={.status.conditions[?(@.type=="Paused")].status}'
vctl -n "${DEMO_NS}" unpause vm "${VM}"; ok "unpaused"
pause

log "Stop (VMI + pod deleted, VM object stays) and start again:"
vctl -n "${DEMO_NS}" stop "${VM}"
wait_until 120 "VMI gone" sh -c "! kubectl --context ${KCTX} -n ${DEMO_NS} get vmi ${VM}"
k get vm -n "${DEMO_NS}" "${VM}"
vctl -n "${DEMO_NS}" start "${VM}"
wait_until 300 "VMI ${VM} Ready again" vmi_ready "${VM}"
echo "  Argo CD leaves runStrategy alone (ignoreDifferences) - check: ./scripts/status.sh"
echo "  Serial console: virtctl --context ${KCTX} -n ${DEMO_NS} console ${VM}   (cirros / gocubsgo, Ctrl+] to exit)"
