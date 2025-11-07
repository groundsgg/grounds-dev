#!/usr/bin/env bash
# Deploy Keycloak operator and instance
# Provides fancy console output with progress indicators

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
project_root="$(cd "${here}/.." && pwd)"

# Wait for CRD to be available
wait_for_crd() {
    local crd="$1"
    local timeout="${2:-120}"
    local count=0
    
    log_info "Waiting for CRD: ${crd}"
    
    while [ $count -lt $timeout ]; do
        if kubectl get crd "${crd}" >/dev/null 2>&1; then
            log_success "CRD ${crd} is ready"
            return 0
        fi
        log_info "Waiting for CRD: ${crd} (${count}s/${timeout}s)..."
        sleep 2
        count=$((count + 2))
    done
    
    log_error "Timeout waiting for CRD: ${crd}"
    return 1
}

# Main execution
main() {
    log_step "Deploying Keycloak operator and instance..."
    
    # Check if OLM is ready
    log_info "Checking if OLM is ready..."
    if kubectl wait --for=condition=ready pod -l app=olm-operator -n olm --timeout=60s 2>/dev/null; then
        log_success "OLM is ready"
    else
        log_warning "OLM may still be starting, continuing anyway..."
    fi
    
    # Wait for OLM CRDs to be available
    log_info "Waiting for OLM CRDs to be available..."
    log_info "Checking available CRDs..."
    kubectl get crd | grep -i operator || log_warning "No operator CRDs found yet"
    
    if ! wait_for_crd "operatorgroups.operators.coreos.com" 120; then
        log_error "OperatorGroup CRD is not available. OLM may not be fully installed."
        log_info "Available CRDs:"
        kubectl get crd | grep -i operator || true
        log_info "Check OLM status with: kubectl get pods -n olm"
        exit 1
    fi
    wait_for_crd "subscriptions.operators.coreos.com" 120 || log_warning "Subscription CRD check failed, continuing..."
    wait_for_crd "catalogsources.operators.coreos.com" 120 || log_warning "CatalogSource CRD check failed, continuing..."
    
    # Create catalog source
    log_info "Creating OperatorHub catalog source if needed..."
    if kubectl apply -f "${project_root}/manifests/keycloak-operator-catalog.yaml" 2>/dev/null; then
        log_success "Catalog source created or already exists"
    else
        log_warning "Catalog source may already exist or OLM not fully ready"
    fi
    
    # Create operator group (required before subscription)
    log_info "Creating Keycloak operator group..."
    if kubectl apply -f "${project_root}/manifests/keycloak-operatorgroup.yaml"; then
        log_success "Operator group created"
    else
        log_error "Failed to create operator group"
        exit 1
    fi
    
    # Install operator subscription
    log_info "Installing Keycloak operator subscription..."
    kubectl apply -f "${project_root}/manifests/keycloak-operator-subscription.yaml"
    log_success "Keycloak operator subscription created"
    
    # Wait for operator to be ready
    log_info "Waiting for Keycloak operator to be ready..."
    timeout=300
    operator_ready=false
    
    while [ $timeout -gt 0 ]; do
        if kubectl get csv -n keycloak 2>/dev/null | grep -q "keycloak.*Succeeded"; then
            log_success "Keycloak operator is ready!"
            operator_ready=true
            break
        fi
        log_info "Waiting for Keycloak operator (${timeout} seconds remaining)..."
        sleep 10
        timeout=$((timeout - 10))
    done
    
    if [ "$operator_ready" = false ]; then
        log_error "Timeout waiting for Keycloak operator to be ready"
        log_warning "Operator may still be installing. Check with: kubectl get csv -n keycloak"
        exit 1
    fi
    
    # Create database secret
    log_info "Creating Keycloak database secret..."
    kubectl apply -f "${project_root}/manifests/keycloak-db-secret.yaml"
    log_success "Database secret created"
    
    # Deploy Traefik middleware for X-Forwarded-* headers (required before Keycloak ingress)
    log_info "Deploying Traefik middleware for X-Forwarded-* headers..."
    if kubectl apply -f "${project_root}/manifests/traefik-keycloak-headers-middleware.yaml" 2>/dev/null; then
        log_success "Traefik middleware created"
    else
        log_warning "Traefik middleware may already exist or CRD not ready"
    fi
    
    # Deploy Keycloak instance
    log_info "Deploying Keycloak instance..."
    kubectl apply -f "${project_root}/manifests/keycloak.yaml"
    log_success "Keycloak instance deployment initiated"
    
    log_step "Keycloak deployment completed! 🎉"
    log_info "Check status with: kubectl get keycloak -n keycloak"
    log_info "Check pods with: kubectl get pods -n keycloak"
}

# Run main function
main "$@"
