# shellcheck shell=bash
# Central version pins and names. Sourced by every script.
# Versions verified against upstream release pages on 2026-11-07.

# --- KubeVirt v1.9.0 (2026-07-30) + CDI v1.66.x (pairs with KubeVirt 1.9) ---
# NOTE: also pinned in gitops/platform/*-operator/kustomization.yaml - bump both.
export KUBEVIRT_VERSION="${KUBEVIRT_VERSION:-v1.9.0}"
export CDI_VERSION="${CDI_VERSION:-v1.66.1}"

# --- Colima VM: vz + nested virtualisation => real /dev/kvm (needs M3+ and macOS 15+) ---
export COLIMA_PROFILE="${COLIMA_PROFILE:-kubevirt}"
export COLIMA_CPUS="${COLIMA_CPUS:-8}"
export COLIMA_MEMORY_GIB="${COLIMA_MEMORY_GIB:-16}"
export COLIMA_DISK_GIB="${COLIMA_DISK_GIB:-80}"

# Point docker/kind at the Colima daemon for this shell only. Docker Desktop's
# context (and the clusters running on it) are left untouched.
export DOCKER_CONTEXT="colima-${COLIMA_PROFILE}"
export KIND_EXPERIMENTAL_PROVIDER=docker

# --- kind (v0.33.0; same pinned node image as velero-kind-dr-lab) ---
export KIND_NODE_IMAGE="${KIND_NODE_IMAGE:-kindest/node:v1.35.8@sha256:07b2536e30b803ed61d1677a79df6115f798ce64c80f9e22f6ed45afd09323c0}"
export CLUSTER_NAME="${CLUSTER_NAME:-kubevirt-lab}"
export KCTX="kind-${CLUSTER_NAME}"

# --- Argo CD (argo-helm chart) ---
export ARGOCD_CHART_VERSION="${ARGOCD_CHART_VERSION:-10.7.1}"

# --- In-lab Git server: Gitea container on the 'kind' docker network ---
export GITEA_IMAGE="${GITEA_IMAGE:-docker.gitea.com/gitea:1.26}"
export GITEA_CONTAINER="${GITEA_CONTAINER:-gitea}"
export GITEA_VOLUME="${GITEA_VOLUME:-kubevirt-lab-gitea-data}"
export GITEA_HOST_PORT="${GITEA_HOST_PORT:-3300}"
export GITEA_USER="${GITEA_USER:-lab}"
export GITEA_PASSWORD="${GITEA_PASSWORD:-lab-gitea-pass}"   # throwaway lab value
export GITEA_REPO="${GITEA_REPO:-kubevirt-kind-demo}"
# URL as seen from inside the cluster (docker DNS on the 'kind' network)
export GITOPS_REPO_URL="${GITOPS_REPO_URL:-http://${GITEA_CONTAINER}:3000/${GITEA_USER}/${GITEA_REPO}.git}"
export GITOPS_REVISION="${GITOPS_REVISION:-main}"

# --- Demo ---
export DEMO_NS="${DEMO_NS:-vm-demo}"

# --- Paths ---
LAB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export LAB_ROOT
export STATE_DIR="${LAB_ROOT}/.state"
export BIN_DIR="${LAB_ROOT}/bin"
export JQ_DIR="${LAB_ROOT}/jq"
export PATH="${BIN_DIR}:${PATH}"
