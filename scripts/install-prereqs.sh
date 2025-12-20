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

# Detect OS
detect_os() {
    if [[ "${OSTYPE}" == "linux-gnu"* ]]; then
        local has_apt has_yum has_pacman
        has_apt=$(command_exists apt-get)
        has_yum=$(command_exists yum)
        has_pacman=$(command_exists pacman)
        
        if [[ "${has_apt}" -eq 0 ]]; then
            echo "ubuntu"
        elif [[ "${has_yum}" -eq 0 ]]; then
            echo "rhel"
        elif [[ "${has_pacman}" -eq 0 ]]; then
            echo "arch"
        else
            echo "linux"
        fi
    elif [[ "${OSTYPE}" == "darwin"* ]]; then
        echo "macos"
    elif [[ "${OSTYPE}" == "msys" ]] || [[ "${OSTYPE}" == "cygwin" ]]; then
        echo "windows"
    else
        echo "unknown"
    fi
}

# Install Docker
install_docker() {
    local os="$1"
    log_info "Installing Docker..."
    
    case "${os}" in
        "ubuntu")
            local docker_exists
            docker_exists=$(command_exists docker)
            if [[ "${docker_exists}" -ne 0 ]]; then
                curl -fsSL https://get.docker.com | sh
                sudo usermod -aG docker "${USER}"
                log_success "Docker installed. Please log out and back in for group changes to take effect."
            else
                log_success "Docker already installed"
            fi
            ;;
        "macos")
            local docker_exists
            docker_exists=$(command_exists docker)
            if [[ "${docker_exists}" -ne 0 ]]; then
                log_warning "Please install Docker Desktop for macOS from https://www.docker.com/products/docker-desktop"
                log_info "Or install via Homebrew: brew install --cask docker"
            else
                log_success "Docker already installed"
            fi
            ;;
        *)
            log_warning "Please install Docker manually for your OS"
            ;;
    esac
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
        log_warning "Docker daemon is not running. Please start Docker and try again."
        log_info "On Linux: sudo systemctl start docker"
        log_info "On macOS: Start Docker Desktop"
        return 1
    fi
    return 0
}

# Check prerequisites only
check_prereqs() {
    log_info "Checking prerequisites..."
    local missing=()
    local docker_exists k3d_exists kubectl_exists helm_exists helmfile_exists devspace_exists
    
    docker_exists=$(command_exists docker)
    k3d_exists=$(command_exists k3d)
    kubectl_exists=$(command_exists kubectl)
    helm_exists=$(command_exists helm)
    helmfile_exists=$(command_exists helmfile)
    devspace_exists=$(command_exists devspace)
    
    if [[ "${docker_exists}" -ne 0 ]]; then
        missing+=("docker")
    fi
    
    if [[ "${k3d_exists}" -ne 0 ]]; then
        missing+=("k3d")
    fi
    
    if [[ "${kubectl_exists}" -ne 0 ]]; then
        missing+=("kubectl")
    fi
    
    if [[ "${helm_exists}" -ne 0 ]]; then
        missing+=("helm")
    fi
    
    if [[ "${helmfile_exists}" -ne 0 ]]; then
        missing+=("helmfile")
    fi
    
    if [[ "${devspace_exists}" -ne 0 ]]; then
        missing+=("devspace")
    fi
    
    if [[ ${#missing[@]} -eq 0 ]]; then
        log_success "All prerequisites found"
        return 0
    else
        log_warning "Missing prerequisites: ${missing[*]}"
        return 1
    fi
}

# Main installation function
main() {
    # Check if --check-only flag is provided
    if [[ "${1:-}" == "--check-only" ]]; then
        check_prereqs
        return $?
    fi
    
    log_step "Checking and installing prerequisites for Grounds Development Infrastructure..."
    
    local os=$(detect_os)
    log_info "Detected OS: ${os}"
    
    # Install prerequisites
    install_docker "${os}"
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
