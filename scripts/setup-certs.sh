#!/usr/bin/env bash

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${here}/common.sh"

readonly CERTS_DIR="${here}/../certs"
readonly LOCAL_DOMAIN="${LOCAL_DOMAIN:-127.0.0.1.sslip.io}"

setup_certs() {
    log_step "Setting up local TLS certificates for *.${LOCAL_DOMAIN}..."

    # Check if mkcert is installed
    if ! command -v mkcert >/dev/null 2>&1; then
        log_error "mkcert is required but not installed. Run 'make install-prereqs' first."
        exit 1
    fi

    # Ensure mkcert CA is installed in the local (WSL/Linux) trust store
    mkcert -install 2>/dev/null || true

    mkdir -p "${CERTS_DIR}"

    local cert_file="${CERTS_DIR}/local-tls.pem"
    local key_file="${CERTS_DIR}/local-tls-key.pem"

    # Generate wildcard certificate if it doesn't exist
    if [[ -f "${cert_file}" && -f "${key_file}" ]]; then
        log_success "Certificates already exist for *.${LOCAL_DOMAIN}"
    else
        log_info "Generating wildcard certificate for ${LOCAL_DOMAIN} and *.${LOCAL_DOMAIN}..."
        mkcert \
            -cert-file "${cert_file}" \
            -key-file "${key_file}" \
            "${LOCAL_DOMAIN}" "*.${LOCAL_DOMAIN}"
        log_success "Certificates generated in certs/"
    fi

    # Create TLS secret in all relevant namespaces
    log_info "Creating TLS secrets in Kubernetes namespaces..."
    for ns in infra databases games api agones keycloak; do
        kubectl create secret tls grounds-local-tls \
            --cert="${cert_file}" \
            --key="${key_file}" \
            --namespace="${ns}" \
            --dry-run=client -o yaml | kubectl apply -f -
    done
    log_success "TLS secret 'grounds-local-tls' created in all namespaces"

    log_info ""
    log_info "Services will be available at:"
    log_info "  https://demo.${LOCAL_DOMAIN}"
    log_info "  https://api.${LOCAL_DOMAIN}"
    log_info ""
    log_info "DNS is handled automatically by sslip.io — no /etc/hosts needed!"
    log_info ""
    log_info "To trust the CA in your Windows browser, run:"
    log_info "  make trust-ca"
    log_info ""
}

setup_certs
