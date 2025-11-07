#!/usr/bin/env bash
# Prerequisites installation script for Grounds Development Infrastructure
# Automatically installs missing dependencies for local Kubernetes development

# set -euo pipefail

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

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Detect OS
detect_os() {
    if [[ "${OSTYPE}" == "linux-gnu"* ]]; then
        local has_apt has_yum has_pacman
        command_exists apt-get
        has_apt=$?
        command_exists yum
        has_yum=$?
        command_exists pacman
        has_pacman=$?
        
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
            command_exists docker
            docker_exists=$?
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
            command_exists docker
            docker_exists=$?
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
    command_exists k3d
    k3d_exists=$?
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
    command_exists kubectl
    kubectl_exists=$?
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
    command_exists helm
    helm_exists=$?
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
    command_exists helmfile
    helmfile_exists=$?
    if [[ "${helmfile_exists}" -ne 0 ]]; then
        log_info "Installing Helmfile..."
        local helmfile_version="v0.156.0"
        curl -L "https://github.com/helmfile/helmfile/releases/download/${helmfile_version}/helmfile_${helmfile_version#v}_linux_amd64.tar.gz" | tar xz
        sudo mv helmfile /usr/local/bin/
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
    
    command_exists docker
    docker_exists=$?
    command_exists k3d
    k3d_exists=$?
    command_exists kubectl
    kubectl_exists=$?
    command_exists helm
    helm_exists=$?
    command_exists helmfile
    helmfile_exists=$?
    command_exists devspace
    devspace_exists=$?
    
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
