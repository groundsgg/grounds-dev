#!/usr/bin/env bash

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${here}/common.sh"

# Check if kubectl is available
check_kubectl() {
    if ! command -v kubectl >/dev/null 2>&1; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
}

# Check cluster connectivity
check_cluster() {
    log_info "Checking cluster connectivity..."
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    log_success "Cluster is accessible"
}

# Get cluster status
get_cluster_status() {
    log_step "Getting cluster status..."
    
    echo ""
    log_info "📊 Cluster Nodes:"
    kubectl get nodes -o wide
    
    echo ""
    log_info "📦 All Pods:"
    kubectl get pods -A
    
    echo ""
    log_info "🔧 Services:"
    kubectl get services -A
}

# Wait for pods to be ready
wait_for_pods() {
    local namespace="$1"
    local selector="$2"
    local timeout="${3:-300}"
    
    log_info "Waiting for pods in namespace '${namespace}' with selector '${selector}'"
    
    if kubectl wait --for=condition=ready pod -l "${selector}" -n "${namespace}" --timeout="${timeout}s" >/dev/null 2>&1; then
        log_success "Pods are ready in namespace '${namespace}'"
        return 0
    else
        log_warning "Timeout waiting for pods in namespace '${namespace}'"
        return 1
    fi
}

# Check namespace exists
check_namespace() {
    local namespace="$1"
    
    if kubectl get namespace "${namespace}" >/dev/null 2>&1; then
        log_success "Namespace '${namespace}' exists"
        return 0
    else
        log_warning "Namespace '${namespace}' does not exist"
        return 1
    fi
}

# Get pod logs
get_pod_logs() {
    local namespace="$1"
    local pod="$2"
    local lines="${3:-50}"
    
    log_info "Getting logs for pod '${pod}' in namespace '${namespace}'"
    kubectl logs -n "${namespace}" "${pod}" --tail="${lines}"
}

# Port forward helper
port_forward() {
    local namespace="$1"
    local service="$2"
    local local_port="$3"
    local service_port="$4"
    
    log_info "Port forwarding ${service}:${service_port} to localhost:${local_port}"
    kubectl port-forward -n "${namespace}" "service/${service}" "${local_port}:${service_port}"
}

# Main function for script usage
main() {
    case "${1:-help}" in
        "status")
            check_kubectl
            check_cluster
            get_cluster_status
            ;;
        "wait-pods")
            if [[ $# -lt 3 ]]; then
                log_error "Usage: $0 wait-pods <namespace> <selector> [timeout]"
                exit 1
            fi
            wait_for_pods "$2" "$3" "${4:-300}"
            ;;
        "check-ns")
            if [[ $# -lt 2 ]]; then
                log_error "Usage: $0 check-ns <namespace>"
                exit 1
            fi
            check_namespace "$2"
            ;;
        "logs")
            if [[ $# -lt 3 ]]; then
                log_error "Usage: $0 logs <namespace> <pod> [lines]"
                exit 1
            fi
            get_pod_logs "$2" "$3" "${4:-50}"
            ;;
        "port-forward")
            if [[ $# -lt 5 ]]; then
                log_error "Usage: $0 port-forward <namespace> <service> <local-port> <service-port>"
                exit 1
            fi
            port_forward "$2" "$3" "$4" "$5"
            ;;
        "help"|*)
            log_info "Kubernetes Helper Script"
            log_info "Usage:"
            echo "  $0 status                    - Get cluster status"
            echo "  $0 wait-pods <ns> <selector>  - Wait for pods to be ready"
            echo "  $0 check-ns <namespace>       - Check if namespace exists"
            echo "  $0 logs <ns> <pod> [lines]    - Get pod logs"
            echo "  $0 port-forward <ns> <svc> <local> <remote> - Port forward service"
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
