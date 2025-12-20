#!/usr/bin/env bash

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${here}/common.sh"

# Spinner characters
spinner_chars=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
spinner_index=0

show_spinner() {
    printf "\r%s %s" "${spinner_chars[${spinner_index}]}" "$1"
    spinner_index=$(( (spinner_index + 1) % ${#spinner_chars[@]} ))
}

wait_for_crd() {
    local crd="$1"
    local timeout="${2:-60}"
    local count=0
    
    log_info "Waiting for CRD: ${crd}"
    
    while [[ "${count}" -lt "${timeout}" ]]; do
        if kubectl get crd "${crd}" >/dev/null 2>&1; then
            log_success "CRD ${crd} is ready"
            return 0
        fi
        
        show_spinner "Waiting for CRD: ${crd} (${count}s/${timeout}s)"
        sleep 2
        count=$((count + 2))
    done
    
    log_error "Timeout waiting for CRD: ${crd}"
    return 1
}

main() {
    log_info "Starting CRD readiness check..."
    
    # Required Agones CRDs
    local crds=("fleets.agones.dev" "gameservers.agones.dev")
    
    for crd in "${crds[@]}"; do
        local crd_ready
        wait_for_crd "${crd}" 60
        crd_ready=$?
        if [[ "${crd_ready}" -ne 0 ]]; then
            log_error "Failed to wait for CRD: ${crd}"
            exit 1
        fi
    done
    
    log_success "All required Agones CRDs are ready! 🎉"
}

# Run main function
main "$@"
