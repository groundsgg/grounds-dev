#!/usr/bin/env bash

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${here}/common.sh"

namespace="games"
secret_name="velocity-forwarding-secret"

log_info "Creating ${secret_name} in namespace: ${namespace}"

secret_value="$(head -c 32 /dev/urandom | base64 | tr -d '\n')"

kubectl create secret generic "${secret_name}" \
    -n "${namespace}" \
    --from-literal="secret=${secret_value}" \
    --dry-run=client \
    -o yaml | kubectl apply -f -

log_success "Secret ${secret_name} updated"
