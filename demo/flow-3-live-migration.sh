#!/usr/bin/env bash
# Flow 3: live-migrate the cirros VM to the other worker without stopping it.
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(cd "$(dirname "$0")/.." && pwd)/scripts/lib.sh"
VM=cirros

banner "Flow 3 - live migration (${DEMO_NS}/${VM})"
wait_until 300 "VMI ${VM} Ready" vmi_ready "${VM}"
before="$(k -n "${DEMO_NS}" get vmi "${VM}" -o 'jsonpath={.status.nodeName}')"
ok "running on ${before}"
pause

mig="${VM}-mig-$(date +%s)"
vctl -n "${DEMO_NS}" migrate "${VM}" --migration-name "${mig}" 2>/dev/null || vctl -n "${DEMO_NS}" migrate "${VM}"
log "VirtualMachineInstanceMigration created; watching phase"
wait_until 300 "migration Succeeded" sh -c \
  "kubectl --context ${KCTX} -n ${DEMO_NS} get vmim -o jsonpath='{.items[*].status.phase}' | tr ' ' '\n' | tail -1 | grep -qx Succeeded"

after="$(k -n "${DEMO_NS}" get vmi "${VM}" -o 'jsonpath={.status.nodeName}')"
k get vmi -n "${DEMO_NS}" -o json | jq -r -f "${JQ_DIR}/vmi-summary.jq" | column -t
[ "${before}" != "${after}" ] && ok "${VM}: ${before} -> ${after}, no restart" || warn "node unchanged (${after})"
