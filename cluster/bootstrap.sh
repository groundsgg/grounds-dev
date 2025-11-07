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

# Install kubeconfig for kubectx if available
if command -v kubectx >/dev/null 2>&1; then
    log_info "kubectx detected, installing kubeconfig to ~/.kube/config..."
    
    # Ensure ~/.kube directory exists
    mkdir -p "$HOME/.kube"
    
    # Merge kubeconfigs using kubectl's native merge capability
    if [ -f "$HOME/.kube/config" ]; then
        KUBECONFIG="$HOME/.kube/config:${here}/../kubeconfig" kubectl config view --flatten > /tmp/merged-config
        mv /tmp/merged-config "$HOME/.kube/config"
        log_success "k3d-dev context merged into ~/.kube/config"
    else
        cp "${here}/../kubeconfig" "$HOME/.kube/config"
        log_success "kubeconfig installed to ~/.kube/config"
    fi
    
    log_info "You can now use: kubectx k3d-dev"
else
    log_info "kubectx not found, skipping kubeconfig installation to ~/.kube/"
fi

# Install OLM (Operator Lifecycle Manager)
log_step "Installing OLM (Operator Lifecycle Manager) v0.35.0..."
if kubectl get deployment olm-operator -n olm >/dev/null 2>&1; then
    log_info "OLM is already installed, skipping installation"
else
    log_info "Downloading OLM installation script..."
    install_script="/tmp/olm-install.sh"
    curl -L https://github.com/operator-framework/operator-lifecycle-manager/releases/download/v0.35.0/install.sh -o "${install_script}"
    chmod +x "${install_script}"
    
    log_info "Installing OLM v0.35.0..."
    "${install_script}" v0.35.0
    
    # Wait for OLM to be ready
    log_info "Waiting for OLM to be ready..."
    max_retries=30
    retry_count=0
    olm_ready=false
    
    while [ $retry_count -lt $max_retries ]; do
        if kubectl get deployment olm-operator -n olm >/dev/null 2>&1 && \
           kubectl get deployment catalog-operator -n olm >/dev/null 2>&1 && \
           kubectl rollout status deployment/olm-operator -n olm --timeout=10s >/dev/null 2>&1 && \
           kubectl rollout status deployment/catalog-operator -n olm --timeout=10s >/dev/null 2>&1; then
            olm_ready=true
            break
        fi
        retry_count=$((retry_count + 1))
        log_info "Waiting for OLM deployments (attempt $retry_count/$max_retries)..."
        sleep 10
    done
    
    if [ "$olm_ready" = true ]; then
        log_success "OLM installed and ready!"
    else
        log_warning "OLM installation may still be in progress, continuing..."
    fi
    
    # Clean up installation script
    rm -f "${install_script}"
fi

# Create namespaces
log_info "Creating namespaces..."
for ns in infra databases games api keycloak; do
    log_info "Creating namespace: ${ns}"
    kubectl create namespace "${ns}" --dry-run=client -o yaml | kubectl apply -f -
done
log_success "Namespaces created: infra, databases, games, api, keycloak"

# Load .env file if it exists
env_file="${here}/../.env"
if [ -f "${env_file}" ]; then
    log_info "Loading environment variables from .env file..."
    set -a
    # shellcheck source=/dev/null
    source "${env_file}"
    set +a
    log_success "Environment variables loaded from .env"
else
    log_warning ".env file not found at ${env_file}"
fi

# Create GHCR pull secret if credentials are provided
if [ -n "${GHCR_USERNAME:-}" ] && [ -n "${GHCR_TOKEN:-}" ]; then
    log_step "Creating GHCR pull secret..."
    
    # Create secret in default namespace
    log_info "Creating ghcr-pull-secret in default namespace..."
    kubectl create secret docker-registry ghcr-pull-secret \
        --docker-server=ghcr.io \
        --docker-username="${GHCR_USERNAME}" \
        --docker-password="${GHCR_TOKEN}" \
        --namespace=default \
        --dry-run=client -o yaml | kubectl apply -f -
    log_success "GHCR pull secret created in default namespace"
    
    # Function to patch service account with GHCR pull secret
    patch_service_account() {
        local namespace=$1
        # Check if the secret already exists in imagePullSecrets
        if kubectl get serviceaccount default -n "${namespace}" -o jsonpath='{.imagePullSecrets[*].name}' 2>/dev/null | grep -q "ghcr-pull-secret"; then
            log_info "GHCR pull secret already configured in default service account for namespace: ${namespace}"
        else
            log_info "Patching default service account in namespace: ${namespace}"
            # Create imagePullSecrets array if it doesn't exist
            if ! kubectl get serviceaccount default -n "${namespace}" -o jsonpath='{.imagePullSecrets}' 2>/dev/null | grep -q "."; then
                kubectl patch serviceaccount default \
                    --namespace="${namespace}" \
                    --type=json \
                    -p='[{"op": "add", "path": "/imagePullSecrets", "value": []}]' || true
            fi
            # Add the secret to imagePullSecrets
            kubectl patch serviceaccount default \
                --namespace="${namespace}" \
                --type=json \
                -p='[{"op": "add", "path": "/imagePullSecrets/-", "value": {"name": "ghcr-pull-secret"}}]' || true
            log_success "Default service account patched in namespace: ${namespace}"
        fi
    }
    
    # Patch default service account in default namespace
    patch_service_account default
    
    # Create secret and patch service accounts in all namespaces
    for ns in infra databases games api keycloak; do
        log_info "Creating ghcr-pull-secret in namespace: ${ns}"
        kubectl create secret docker-registry ghcr-pull-secret \
            --docker-server=ghcr.io \
            --docker-username="${GHCR_USERNAME}" \
            --docker-password="${GHCR_TOKEN}" \
            --namespace="${ns}" \
            --dry-run=client -o yaml | kubectl apply -f -
        
        patch_service_account "${ns}"
    done
    
    log_success "GHCR pull secret configured globally across all namespaces"
else
    log_warning "GHCR credentials not found (GHCR_USERNAME or GHCR_TOKEN missing), skipping GHCR pull secret creation"
    log_info "To enable GHCR authentication, set GHCR_USERNAME and GHCR_TOKEN in your .env file"
fi

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
