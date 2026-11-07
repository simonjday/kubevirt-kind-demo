#!/usr/bin/env bash
# Starts a dedicated Colima VM (vz + nested virt) and proves /dev/kvm exists in it.
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

banner "colima profile: ${COLIMA_PROFILE}"

if colima status --profile "${COLIMA_PROFILE}" >/dev/null 2>&1; then
  ok "colima '${COLIMA_PROFILE}' already running"
else
  colima start --profile "${COLIMA_PROFILE}" \
    --vm-type vz --nested-virtualization \
    --cpu "${COLIMA_CPUS}" --memory "${COLIMA_MEMORY_GIB}" --disk "${COLIMA_DISK_GIB}" \
    --runtime docker
fi

# The whole lab hinges on this. If the profile was created earlier without
# nested virt, vmType/nestedVirtualization can't be changed in place.
if colima ssh --profile "${COLIMA_PROFILE}" -- test -c /dev/kvm; then
  ok "/dev/kvm present inside the Colima VM"
else
  die "/dev/kvm missing. Recreate the profile: colima delete --profile ${COLIMA_PROFILE} && $0"
fi

# kind + KubeVirt exhaust the default 128 inotify instances: virt-handler panics with
# "Failed to create an inotify watcher: too many open files". Not persisted across
# VM restarts, so this runs on every up.sh.
colima ssh --profile "${COLIMA_PROFILE}" -- sudo sysctl -q -w \
  fs.inotify.max_user_instances=8192 fs.inotify.max_user_watches=1048576
ok "inotify limits raised (instances=8192, watches=1048576)"

docker context inspect "${DOCKER_CONTEXT}" >/dev/null 2>&1 \
  || die "docker context '${DOCKER_CONTEXT}' not found (colima should create it)"
docker info --format '{{.OperatingSystem}} / {{.Architecture}} / {{.NCPU}} CPU' \
  | sed 's/^/  docker: /'
ok "docker CLI -> ${DOCKER_CONTEXT} (this shell only; Docker Desktop untouched)"
