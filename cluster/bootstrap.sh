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

# Check if cluster already exists
if k3d cluster list | grep -q "^dev "; then
    log_warning "Cluster 'dev' already exists, checking health..."
    
    # Check if cluster is healthy with retry
    max_retries=3
    retry_count=0
    cluster_healthy=false
    
    while [ $retry_count -lt $max_retries ]; do
        if kubectl cluster-info >/dev/null 2>&1 && kubectl get nodes >/dev/null 2>&1; then
            cluster_healthy=true
            break
        fi
        retry_count=$((retry_count + 1))
        log_warning "Cluster health check failed (attempt $retry_count/$max_retries), retrying in 5 seconds..."
        sleep 5
    done
    
    if [ "$cluster_healthy" = true ]; then
        log_success "Cluster 'dev' is healthy, skipping creation"
    else
        log_warning "Cluster 'dev' exists but is unhealthy after $max_retries attempts, recreating..."
        k3d cluster delete dev
        log_step "Creating k3d cluster 'dev'..."
        k3d cluster create --config "${here}/k3d.yaml"
        log_success "Cluster 'dev' created successfully"
    fi
else
    log_step "Creating k3d cluster 'dev'..."
    k3d cluster create --config "${here}/k3d.yaml"
    log_success "Cluster 'dev' created successfully"
fi

# Set kubectl context
log_info "Setting kubectl context to k3d-dev..."
kubectl config use-context k3d-dev
log_success "kubectl context set to k3d-dev"

# Export kubeconfig to project root
log_info "Exporting kubeconfig to ./kubeconfig..."
k3d kubeconfig get dev > "${here}/../kubeconfig"
log_success "Kubeconfig exported to ./kubeconfig"

# Create namespaces
log_info "Creating namespaces..."
for ns in infra databases games api; do
    log_info "Creating namespace: ${ns}"
    kubectl create namespace "${ns}" --dry-run=client -o yaml | kubectl apply -f -
done
log_success "Namespaces created: infra, databases, games, api"

# Add Helm repositories
log_step "Adding Helm repositories..."
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add agones https://agones.dev/chart/stable
log_success "Helm repositories added"

# Update Helm repositories
log_info "Updating Helm repository cache..."
helm repo update
log_success "Helm repositories updated"

# Verify cluster is ready with retry
log_info "Verifying cluster readiness..."
max_retries=5
retry_count=0
cluster_ready=false

while [ $retry_count -lt $max_retries ]; do
    if kubectl get nodes >/dev/null 2>&1; then
        cluster_ready=true
        break
    fi
    retry_count=$((retry_count + 1))
    log_warning "Cluster readiness check failed (attempt $retry_count/$max_retries), retrying in 10 seconds..."
    sleep 10
done

if [ "$cluster_ready" = true ]; then
    kubectl get nodes
    log_success "Cluster is ready!"
else
    log_error "Cluster failed to become ready after $max_retries attempts"
    exit 1
fi

log_step "Bootstrap completed successfully! 🎉"
log_info "Next steps:"
echo -e "  ${CYAN}•${NC} Run ${WHITE}make up${NC} to deploy the full stack"
echo -e "  ${CYAN}•${NC} Run ${WHITE}make status${NC} to check deployment status"
echo -e "  ${CYAN}•${NC} Access services at ${WHITE}http://localhost${NC}"
echo -e "  ${CYAN}•${NC} Use kubeconfig: ${WHITE}export KUBECONFIG=\$(pwd)/kubeconfig${NC}"
