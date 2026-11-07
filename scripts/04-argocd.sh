#!/usr/bin/env bash
# Bootstraps Argo CD with Helm, then hands everything else to the app-of-apps.
# This and the root Application are the only imperative applies in the lab.
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

banner "argo cd ${ARGOCD_CHART_VERSION} + app-of-apps"

helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update argo >/dev/null
helm upgrade --install argocd argo/argo-cd \
  --kube-context "${KCTX}" --namespace argocd --create-namespace \
  --version "${ARGOCD_CHART_VERSION}" \
  -f "${LAB_ROOT}/config/argocd-values.yaml" \
  --wait --timeout 10m >/dev/null
ok "argo cd installed"

# Root app: repoURL is injected here and patched into every child Application,
# so pointing the lab at GitHub instead of Gitea is a single env var.
sed -e "s#__REPO_URL__#${GITOPS_REPO_URL}#g" -e "s#__REVISION__#${GITOPS_REVISION}#g" \
  "${LAB_ROOT}/gitops/bootstrap/root-app.yaml" | k apply -f - >/dev/null
ok "root Application -> ${GITOPS_REPO_URL}@${GITOPS_REVISION}"

log "waiting for KubeVirt + CDI (first sync pulls ~1GB of images)"
wait_until 900 "KubeVirt phase=Deployed" kubevirt_deployed
wait_until 600 "CDI phase=Deployed" cdi_deployed
