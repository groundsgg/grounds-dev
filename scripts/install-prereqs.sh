#!/usr/bin/env bash

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${here}/common.sh"

# Check if command exists
command_exists() {
    if command -v "$1" >/dev/null 2>&1; then
        echo 0
    else
        echo 1
    fi
}

# Install k3d
install_k3d() {
    local k3d_exists
    k3d_exists=$(command_exists k3d)
    if [[ "${k3d_exists}" -ne 0 ]]; then
        log_info "Installing k3d..."
        curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
        log_success "k3d installed"
    else
        log_success "k3d already installed"
    fi
}

# Install kubectl
install_kubectl() {
    local kubectl_exists
    kubectl_exists=$(command_exists kubectl)
    if [[ "${kubectl_exists}" -ne 0 ]]; then
        log_info "Installing kubectl..."
        local kubectl_version=$(curl -L -s https://dl.k8s.io/release/stable.txt)
        curl -LO "https://dl.k8s.io/release/${kubectl_version}/bin/linux/amd64/kubectl"
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/
        log_success "kubectl installed"
    else
        log_success "kubectl already installed"
    fi
}

# Install Helm
install_helm() {
    local helm_exists
    helm_exists=$(command_exists helm)
    if [[ "${helm_exists}" -ne 0 ]]; then
        log_info "Installing Helm..."
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
        log_success "Helm installed"
    else
        log_success "Helm already installed"
    fi
}

# Install Helmfile
install_helmfile() {
    local helmfile_exists
    helmfile_exists=$(command_exists helmfile)
    if [[ "${helmfile_exists}" -ne 0 ]]; then
        log_info "Installing Helmfile..."
        local helmfile_version="v1.2.3"
        local tmp_dir
        tmp_dir="$(mktemp -d)"
        curl -L "https://github.com/helmfile/helmfile/releases/download/${helmfile_version}/helmfile_${helmfile_version#v}_linux_amd64.tar.gz" | tar -xz -C "${tmp_dir}"
        sudo mv "${tmp_dir}/helmfile" /usr/local/bin/
        rm -rf "${tmp_dir}"
        log_success "Helmfile installed"
    else
        log_success "Helmfile already installed"
    fi
}

# Install DevSpace
install_devspace() {
    if ! command -v devspace >/dev/null 2>&1; then
        log_info "Installing DevSpace..."
        local devspace_version="v6.3.18"
        local temp_file=$(mktemp)
        curl -L "https://github.com/loft-sh/devspace/releases/download/${devspace_version}/devspace-linux-amd64" -o "${temp_file}"
        chmod +x "${temp_file}"
        sudo mv "${temp_file}" /usr/local/bin/devspace
        log_success "DevSpace installed"
    else
        log_success "DevSpace already installed"
    fi
}

# Check Docker daemon
check_docker_daemon() {
    if ! docker info >/dev/null 2>&1; then
        log_warning "Docker daemon is not running. Please install or start Docker and try again."
        return 1
    fi
    return 0
}

# Main installation function
main() {
    log_step "Checking and installing prerequisites for Grounds Development Infrastructure..."
    
    # Install prerequisites
    install_k3d
    install_kubectl
    install_helm
    install_helmfile
    install_devspace
    
    # Check Docker daemon
    local daemon_running
    check_docker_daemon
    daemon_running=$?
    if [[ "${daemon_running}" -ne 0 ]]; then
        log_error "Docker daemon is not running. Please start Docker and run 'make up' again."
        exit 1
    fi
    
    log_success "All prerequisites are installed and ready! 🎉"
    log_info "You can now run 'make up' to start the development environment."
}

# Run main function
main "$@"
