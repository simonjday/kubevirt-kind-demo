#!/usr/bin/env bash
# The GitOps loop for this lab: commit locally, then push HEAD to the in-lab Gitea.
# Argo CD polls Gitea; --refresh asks it to look now.
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

cd "${LAB_ROOT}"
[ -d .git ] || git init -q -b "${GITOPS_REVISION}"

if ! git rev-parse -q --verify HEAD >/dev/null; then
  git add -A && git commit -qm "Initial KubeVirt-on-kind lab" && ok "initial commit created"
fi
[ -z "$(git status --porcelain)" ] || warn "uncommitted changes are NOT pushed - only committed HEAD ($(git rev-parse --short HEAD))"

# Gitea is a disposable mirror of this checkout, so force is safe here.
git push -q --force \
  "http://${GITEA_USER}:${GITEA_PASSWORD}@127.0.0.1:${GITEA_HOST_PORT}/${GITEA_USER}/${GITEA_REPO}.git" \
  "HEAD:refs/heads/${GITOPS_REVISION}"
ok "pushed $(git rev-parse --short HEAD) -> gitea ${GITEA_USER}/${GITEA_REPO}@${GITOPS_REVISION}"

if [ "${1:-}" = "--refresh" ] && k -n argocd get application root >/dev/null 2>&1; then
  for app in $(k -n argocd get applications -o name); do
    k -n argocd annotate "${app}" argocd.argoproj.io/refresh=normal --overwrite >/dev/null
  done
  ok "argo cd refresh requested"
fi
