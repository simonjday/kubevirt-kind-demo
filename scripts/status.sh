#!/usr/bin/env bash
set -uo pipefail   # no -e: report as much as possible even when parts are missing
# shellcheck source=scripts/lib.sh
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

banner "status: ${KCTX} (docker context ${DOCKER_CONTEXT})"

echo "Argo CD applications (name / wave / sync / health):"
k -n argocd get applications -o json | jq -r -f "${JQ_DIR}/argocd-apps.jq" | column -t | sed 's/^/  /'

echo; echo "Platform:"
printf '  KubeVirt %s  phase=%s\n' "$(k -n kubevirt get kubevirt kubevirt -o 'jsonpath={.status.observedKubeVirtVersion}' 2>/dev/null)" \
  "$(k -n kubevirt get kubevirt kubevirt -o 'jsonpath={.status.phase}' 2>/dev/null || echo missing)"
printf '  CDI      %s  phase=%s\n' "$(k get cdi cdi -o 'jsonpath={.status.observedVersion}' 2>/dev/null)" \
  "$(k get cdi cdi -o 'jsonpath={.status.phase}' 2>/dev/null || echo missing)"
printf '  emulation=%s  (false = hardware KVM)\n' \
  "$(k -n kubevirt get kubevirt kubevirt -o 'jsonpath={.spec.configuration.developerConfiguration.useEmulation}' 2>/dev/null || echo '?')"
echo "  allocatable devices.kubevirt.io/kvm per node:"
k get nodes -o json | jq -r -f "${JQ_DIR}/node-kvm.jq" | column -t | sed 's/^/    /'

echo; echo "VirtualMachines (ns / name / runStrategy / status / ready):"
k get vm -A -o json | jq -r -f "${JQ_DIR}/vm-summary.jq" | column -t | sed 's/^/  /'
echo; echo "VMIs (name / phase / node / ip / migrated):"
k get vmi -A -o json | jq -r -f "${JQ_DIR}/vmi-summary.jq" | column -t | sed 's/^/  /'
echo; echo "Argo CD UI: kubectl --context ${KCTX} -n argocd port-forward svc/argocd-server 8080:80"
echo "  admin password: kubectl --context ${KCTX} -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo "Gitea:  http://127.0.0.1:${GITEA_HOST_PORT}  (${GITEA_USER} / ${GITEA_PASSWORD})"
