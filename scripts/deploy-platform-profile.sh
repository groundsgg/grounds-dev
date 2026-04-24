#!/usr/bin/env bash
# Layers the platform profile onto an existing grounds-dev cluster:
# Zot + vCluster operator + grounds-forge (management-light values).
#
# Pre-req: `make up` has succeeded (local k3d cluster + postgres + agones).
# Pre-req: helm is logged into ghcr.io (private chart pulls):
#   echo <GHCR_PAT> | helm registry login ghcr.io -u <you> --password-stdin

set -euo pipefail

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

: "${KUBECONFIG:=${HOME}/.kube/config}"
export KUBECONFIG

printf "${BLUE}==>${NC} Verifying cluster is up\n"
kubectl cluster-info >/dev/null

printf "${BLUE}==>${NC} Installing zot (local dev values)\n"
helm upgrade --install zot oci://ghcr.io/project-zot/helm-charts/zot \
  --namespace zot --create-namespace \
  --set persistence.enabled=false \
  --wait --timeout 3m

printf "${BLUE}==>${NC} Installing vCluster operator\n"
helm upgrade --install vcluster-operator \
  oci://ghcr.io/loft-sh/charts/vcluster-operator \
  --namespace vcluster-system --create-namespace \
  --wait --timeout 3m

printf "${YELLOW}==>${NC} Keycloak platform realm: deferred\n"
printf "    Add manifests/platform/keycloak-platform-realm.json and re-run\n"
printf "    before exercising /v1/whoami.\n"

printf "${BLUE}==>${NC} Installing grounds-forge (private chart — requires helm login to ghcr.io)\n"
if ! helm show chart oci://ghcr.io/groundsgg/charts/grounds-forge --version 0.3.1 >/dev/null 2>&1; then
  printf "${YELLOW}!!${NC} helm can't pull the private grounds-forge chart.\n"
  printf "    Run: echo <GHCR_PAT> | helm registry login ghcr.io -u <github-user> --password-stdin\n"
  exit 1
fi

helm upgrade --install grounds-forge \
  oci://ghcr.io/groundsgg/charts/grounds-forge --version 0.3.1 \
  --namespace grounds-forge --create-namespace \
  -f "$(dirname "$0")/../manifests/platform/grounds-forge-light.values.yaml" \
  --wait --timeout 5m

printf "${GREEN}==>${NC} Done. grounds-forge at http://platform.localhost\n"
printf "    Try: curl http://platform.localhost/healthz\n"
