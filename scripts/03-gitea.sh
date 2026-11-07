#!/usr/bin/env bash
# Runs Gitea as a container on the 'kind' network (outside the cluster, like the
# SeaweedFS pattern in velero-kind-dr-lab), creates the repo and pushes this checkout.
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

banner "gitea (in-lab Git source for Argo CD)"

docker network inspect kind >/dev/null 2>&1 || die "docker network 'kind' missing - run 02-cluster.sh first"

if docker ps -a --format '{{.Names}}' | grep -qx "${GITEA_CONTAINER}"; then
  docker start "${GITEA_CONTAINER}" >/dev/null
  ok "container ${GITEA_CONTAINER} running"
else
  docker run -d --name "${GITEA_CONTAINER}" --network kind --restart unless-stopped \
    -p "127.0.0.1:${GITEA_HOST_PORT}:3000" \
    -e GITEA__security__INSTALL_LOCK=true \
    -e GITEA__database__DB_TYPE=sqlite3 \
    -e GITEA__server__ROOT_URL="http://${GITEA_CONTAINER}:3000/" \
    -e GITEA__service__DISABLE_REGISTRATION=true \
    -v "${GITEA_VOLUME}:/data" \
    "${GITEA_IMAGE}" >/dev/null
  ok "container ${GITEA_CONTAINER} started (${GITEA_IMAGE})"
fi

wait_until 120 "gitea healthy on 127.0.0.1:${GITEA_HOST_PORT}" \
  curl -fsS "http://127.0.0.1:${GITEA_HOST_PORT}/api/healthz"

if gitea_api GET /user >/dev/null 2>&1; then
  ok "user ${GITEA_USER} exists"
else
  docker exec -u git "${GITEA_CONTAINER}" gitea admin user create \
    --username "${GITEA_USER}" --password "${GITEA_PASSWORD}" \
    --email "${GITEA_USER}@example.com" --admin --must-change-password=false >/dev/null
  ok "user ${GITEA_USER} created"
fi

if gitea_api GET "/repos/${GITEA_USER}/${GITEA_REPO}" >/dev/null 2>&1; then
  ok "repo ${GITEA_USER}/${GITEA_REPO} exists"
else
  gitea_api POST /user/repos \
    "{\"name\":\"${GITEA_REPO}\",\"private\":false,\"default_branch\":\"${GITOPS_REVISION}\"}" >/dev/null
  ok "repo ${GITEA_USER}/${GITEA_REPO} created"
fi

"${LAB_ROOT}/scripts/push.sh"
