#!/usr/bin/env bash

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${here}/common.sh"

trust_ca_windows() {
    log_step "Installing mkcert CA in the Windows certificate store..."

    if ! command -v mkcert >/dev/null 2>&1; then
        log_error "mkcert is not installed. Run 'make install-prereqs' first."
        exit 1
    fi

    local ca_root
    ca_root="$(mkcert -CAROOT)"
    local root_ca="${ca_root}/rootCA.pem"

    if [[ ! -f "${root_ca}" ]]; then
        log_error "Root CA not found at ${root_ca}. Run 'make certs' first to generate certificates."
        exit 1
    fi

    # Check if we're running in WSL
    if ! grep -qi microsoft /proc/version 2>/dev/null; then
        log_warning "This script is designed for WSL2. On native Linux, 'mkcert -install' is sufficient."
        exit 0
    fi

    # Convert WSL path to Windows path
    local win_temp
    win_temp="$(wslpath "$(cmd.exe /C 'echo %TEMP%' 2>/dev/null | tr -d '\r')")"
    local win_ca_dest="${win_temp}/mkcert-rootCA.pem"

    log_info "Copying root CA to Windows temp directory..."
    cp "${root_ca}" "${win_ca_dest}"

    local win_ca_path
    win_ca_path="$(wslpath -w "${win_ca_dest}")"

    log_info "Importing CA into Windows trust store (requires elevated permissions)..."
    log_info "A UAC prompt may appear — please confirm it."

    # Use PowerShell to import the certificate into the Windows trust store
    # This requires admin privileges, so we use Start-Process with -Verb RunAs
    powershell.exe -NoProfile -Command "
        Start-Process powershell -Verb RunAs -Wait -ArgumentList '-NoProfile -Command \"Import-Certificate -FilePath \\\"${win_ca_path}\\\" -CertStoreLocation Cert:\\LocalMachine\\Root\"'
    " 2>/dev/null

    if [[ $? -eq 0 ]]; then
        log_success "Root CA imported into Windows certificate store!"
        log_info "Chrome and Edge will now trust *.${LOCAL_DOMAIN:-127.0.0.1.sslip.io} certificates."
        log_info ""
        log_info "Note for Firefox: Firefox uses its own certificate store."
        log_info "  Either enable 'security.enterprise_roots.enabled' in about:config"
        log_info "  or manually import ${root_ca} in Firefox settings."
    else
        log_warning "Automatic import may have failed. You can manually import:"
        log_info "  1. Open '${root_ca}' in Windows Explorer"
        log_info "  2. Double-click the .pem file"
        log_info "  3. Install Certificate -> Local Machine -> Trusted Root Certification Authorities"
    fi

    # Clean up temp file
    rm -f "${win_ca_dest}" 2>/dev/null || true
}

trust_ca_windows
