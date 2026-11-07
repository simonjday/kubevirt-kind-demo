#!/usr/bin/env bash
# Full build from a clean Mac: Colima VM -> kind -> Gitea -> Argo CD -> KubeVirt/CDI/VMs
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
start=$(date +%s)
"${here}/00-prereqs.sh"
"${here}/01-colima.sh"
"${here}/02-cluster.sh"
"${here}/03-gitea.sh"
"${here}/04-argocd.sh"
"${here}/status.sh"
printf '\n\033[1;32mLab up in %ss.\033[0m Next: ./demo/flow-1-lifecycle.sh\n' "$(( $(date +%s) - start ))"
