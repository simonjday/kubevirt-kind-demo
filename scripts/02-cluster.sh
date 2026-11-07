#!/usr/bin/env bash
# Creates the kind cluster on the Colima daemon and checks every node sees /dev/kvm.
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

banner "kind cluster: ${CLUSTER_NAME}"

if cluster_exists; then
  ok "cluster ${CLUSTER_NAME} already exists"
else
  kind create cluster --name "${CLUSTER_NAME}" --image "${KIND_NODE_IMAGE}" \
    --config "${LAB_ROOT}/config/kind-cluster.yaml" --wait 180s
fi

wait_until 180 "nodes Ready" k wait --for=condition=Ready nodes --all --timeout=5s

# kind nodes are privileged containers, so they inherit /dev/kvm from the VM.
for node in $(kind get nodes --name "${CLUSTER_NAME}"); do
  if docker exec "${node}" test -c /dev/kvm; then ok "${node}: /dev/kvm"
  else die "${node}: no /dev/kvm - KubeVirt would fall back to nothing (useEmulation is false)"; fi
done

# cgroup v1 is deprecated in KubeVirt 1.9 - make sure we're on v2
cg="$(docker exec "${CLUSTER_NAME}-control-plane" stat -fc %T /sys/fs/cgroup)"
[ "${cg}" = "cgroup2fs" ] && ok "cgroup v2" || warn "cgroup fs is '${cg}' (v1 is deprecated in KubeVirt 1.9)"

# Guest images must have an arm64 variant (the VM is aarch64; KVM can't run x86 guests).
for img in quay.io/kubevirt/cirros-container-disk-demo:${KUBEVIRT_VERSION} quay.io/containerdisks/fedora:43; do
  arches="$(docker manifest inspect "${img}" 2>/dev/null | jq -r -f "${JQ_DIR}/image-arch.jq" || echo unknown)"
  case "${arches}" in
    *linux/arm64*) ok "${img}: arm64 available" ;;
    *) warn "${img}: no linux/arm64 in manifest (${arches}) - swap the image in gitops/workloads/demo-vms" ;;
  esac
done
