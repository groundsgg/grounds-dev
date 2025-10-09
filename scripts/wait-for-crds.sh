#!/usr/bin/env bash
# Wait for Agones CRDs to be ready
# Provides fancy console output with spinner and progress indicators

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

# Spinner characters
spinner_chars=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
spinner_index=0

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

# Spinner function
show_spinner() {
    printf "\r${PURPLE}${spinner_chars[$spinner_index]}${NC} $1"
    spinner_index=$(( (spinner_index + 1) % ${#spinner_chars[@]} ))
}

# Wait for CRD function
wait_for_crd() {
    local crd="$1"
    local timeout="${2:-60}"
    local count=0
    
    log_info "Waiting for CRD: $crd"
    
    while [ $count -lt $timeout ]; do
        if kubectl get crd "$crd" >/dev/null 2>&1; then
            log_success "CRD $crd is ready"
            return 0
        fi
        
        show_spinner "Waiting for CRD: $crd (${count}s/${timeout}s)"
        sleep 2
        count=$((count + 2))
    done
    
    log_error "Timeout waiting for CRD: $crd"
    return 1
}

# Main execution
main() {
    log_info "Starting CRD readiness check..."
    
    # Required Agones CRDs
    local crds=("fleets.agones.dev" "gameservers.agones.dev")
    
    for crd in "${crds[@]}"; do
        if ! wait_for_crd "$crd" 60; then
            log_error "Failed to wait for CRD: $crd"
            exit 1
        fi
    done
    
    log_success "All required Agones CRDs are ready! 🎉"
}

# Run main function
main "$@"
