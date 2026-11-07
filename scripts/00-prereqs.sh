#!/usr/bin/env bash
# Host checks + pinned virtctl download.
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

banner "prereqs"

[ "$(uname -s)/$(uname -m)" = "Darwin/arm64" ] || die "this lab targets macOS on Apple Silicon"

chip="$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo unknown)"
case "${chip}" in
  *M1*|*M2*) die "${chip}: Apple nested virtualisation needs M3 or later (use useEmulation: true on Docker Desktop instead)" ;;
  *) ok "chip: ${chip}" ;;
esac

macos_major="$(sw_vers -productVersion | cut -d. -f1)"
[ "${macos_major}" -ge 15 ] || die "macOS $(sw_vers -productVersion): nested virtualisation needs macOS 15+"
ok "macOS $(sw_vers -productVersion)"

need colima  "brew install colima"
need docker  "brew install docker (CLI only is fine)"
need kind    "brew install kind"
need kubectl "brew install kubectl"
need helm    "brew install helm"
need jq      "brew install jq"
need git     "xcode-select --install"
need curl    "should ship with macOS"
ok "CLIs present"

colima start --help 2>&1 | grep -q -- '--nested-virtualization' \
  || die "this colima ($(colima version 2>/dev/null | head -1)) has no --nested-virtualization flag - brew upgrade colima"
ok "colima supports --nested-virtualization"

# Two Linux VMs on a 32GB Mac is tight: Docker Desktop's VM + Colima's.
if pgrep -qf 'com.docker.backend' 2>/dev/null; then
  warn "Docker Desktop is running. Colima needs ${COLIMA_MEMORY_GIB}GiB on top of it."
  warn "Quit Docker Desktop (or stop its kind clusters) if the Mac starts swapping."
fi

# virtctl, pinned to the KubeVirt version
mkdir -p "${BIN_DIR}"
if [ -x "${BIN_DIR}/virtctl" ] && "${BIN_DIR}/virtctl" version --client 2>/dev/null | grep -q "${KUBEVIRT_VERSION}"; then
  ok "virtctl ${KUBEVIRT_VERSION} already in bin/"
else
  log "downloading virtctl ${KUBEVIRT_VERSION} (darwin-arm64)"
  curl -fsSL -o "${BIN_DIR}/virtctl" \
    "https://github.com/kubevirt/kubevirt/releases/download/${KUBEVIRT_VERSION}/virtctl-${KUBEVIRT_VERSION}-darwin-arm64"
  chmod +x "${BIN_DIR}/virtctl"
  xattr -d com.apple.quarantine "${BIN_DIR}/virtctl" 2>/dev/null || true
  ok "virtctl -> bin/virtctl"
fi
