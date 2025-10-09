#!/usr/bin/env bash
# Bootstrap script for Grounds Development Infrastructure (grounds-dev) k3d cluster
# Creates cluster, sets up namespaces, and configures Helm repositories

set -euo pipefail

# Colors and emojis for fancy console output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_step() {
    echo -e "${PURPLE}🚀 $1${NC}"
}

# Get script directory
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log_step "Starting Grounds Development Infrastructure cluster bootstrap..."

# Check prerequisites
log_info "Checking prerequisites..."
command -v k3d >/dev/null 2>&1 || { log_error "k3d is required but not installed. Please install k3d first."; exit 1; }
command -v kubectl >/dev/null 2>&1 || { log_error "kubectl is required but not installed. Please install kubectl first."; exit 1; }
command -v helm >/dev/null 2>&1 || { log_error "helm is required but not installed. Please install helm first."; exit 1; }
log_success "All prerequisites found"

# Create k3d cluster
log_step "Creating k3d cluster 'dev'..."
k3d cluster create --config "$here/k3d.yaml"
log_success "Cluster 'dev' created successfully"

# Set kubectl context
log_info "Setting kubectl context to k3d-dev..."
kubectl config use-context k3d-dev
log_success "kubectl context set to k3d-dev"

# Create namespaces
log_info "Creating namespaces..."
for ns in infra databases games; do
    log_info "Creating namespace: $ns"
    kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done
log_success "Namespaces created: infra, databases, games"

# Add Helm repositories
log_step "Adding Helm repositories..."
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add agones https://agones.dev/chart/stable
log_success "Helm repositories added"

# Update Helm repositories
log_info "Updating Helm repository cache..."
helm repo update
log_success "Helm repositories updated"

# Verify cluster is ready
log_info "Verifying cluster readiness..."
kubectl get nodes
log_success "Cluster is ready!"

log_step "Bootstrap completed successfully! 🎉"
log_info "Next steps:"
echo -e "  ${CYAN}•${NC} Run ${WHITE}make up${NC} to deploy the full stack"
echo -e "  ${CYAN}•${NC} Run ${WHITE}make status${NC} to check deployment status"
echo -e "  ${CYAN}•${NC} Access services at ${WHITE}http://localhost${NC}"
