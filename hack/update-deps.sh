#!/usr/bin/env bash
# =============================================================================
# Update Dependencies Script
# =============================================================================
# This script updates Helm chart dependencies and checks for version updates.
# It can be used locally or in CI to keep dependencies up-to-date.
#
# Usage: ./hack/update-deps.sh [--check|--update|--all]
#   --check   Check for available updates (default)
#   --update  Update Chart.yaml with new versions
#   --all     Update and rebuild Chart.lock
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CHART_FILE="${ROOT_DIR}/Chart.yaml"
CHART_LOCK="${ROOT_DIR}/Chart.lock"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_update() {
    echo -e "${BLUE}[UPDATE]${NC} $1"
}

# Check dependencies
check_helm() {
    if ! command -v helm &> /dev/null; then
        log_error "helm is not installed."
        exit 1
    fi
    
    if ! command -v yq &> /dev/null; then
        log_warn "yq is not installed. Some features may not work."
        log_info "Install it from: https://github.com/mikefarah/yq"
    fi
}

# Add all required Helm repositories
add_repos() {
    log_info "Adding Helm repositories..."
    
    helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
    helm repo add victoriametrics https://victoriametrics.github.io/helm-charts 2>/dev/null || true
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
    helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null || true
    helm repo add jaegertracing https://jaegertracing.github.io/helm-charts 2>/dev/null || true
    helm repo add kiali https://kiali.org/helm-charts 2>/dev/null || true
    
    log_info "Updating Helm repositories..."
    helm repo update
}

# Get latest version of a chart from a repository
get_latest_version() {
    local repo_url="$1"
    local chart_name="$2"
    
    # Map repository URL to repo name
    local repo_name=""
    case "${repo_url}" in
        *grafana*)
            repo_name="grafana"
            ;;
        *victoriametrics*)
            repo_name="victoriametrics"
            ;;
        *prometheus-community*)
            repo_name="prometheus-community"
            ;;
        *bitnami*)
            repo_name="bitnami"
            ;;
        *jaegertracing*)
            repo_name="jaegertracing"
            ;;
        *kiali*)
            repo_name="kiali"
            ;;
        *)
            log_warn "Unknown repository: ${repo_url}"
            return 1
            ;;
    esac
    
    helm search repo "${repo_name}/${chart_name}" --output json 2>/dev/null | \
        jq -r '.[0].version // empty' 2>/dev/null || echo ""
}

# Check for updates
check_updates() {
    log_info "Checking for dependency updates..."
    
    local updates_available=0
    
    # Parse Chart.yaml dependencies
    if command -v yq &> /dev/null; then
        local deps=$(yq e '.dependencies[] | [.name, .version, .repository] | @csv' "${CHART_FILE}" 2>/dev/null)
        
        while IFS=',' read -r name version repository; do
            # Clean up values
            name=$(echo "${name}" | tr -d '"')
            version=$(echo "${version}" | tr -d '"')
            repository=$(echo "${repository}" | tr -d '"')
            
            if [[ -z "${name}" ]]; then
                continue
            fi
            
            # Get latest version
            local latest=$(get_latest_version "${repository}" "${name}")
            
            if [[ -z "${latest}" ]]; then
                log_warn "  Could not check ${name}"
                continue
            fi
            
            # Compare versions (strip the wildcard pattern)
            local current_base=$(echo "${version}" | sed 's/\.\*$//')
            local latest_base=$(echo "${latest}" | cut -d'.' -f1-2)
            
            if [[ "${current_base}" != "${latest_base}" ]] && [[ "${version}" != "${latest}" ]]; then
                log_update "  ${name}: ${version} -> ${latest}"
                updates_available=1
            else
                log_info "  ${name}: ${version} (up to date)"
            fi
        done <<< "${deps}"
    else
        log_warn "yq not available, using helm dependency update"
        helm dependency update "${ROOT_DIR}" 2>&1 | grep -E "(Saving|Deleting)"
    fi
    
    return ${updates_available}
}

# Update Chart.lock
update_lock() {
    log_info "Updating Chart.lock..."
    
    cd "${ROOT_DIR}"
    
    # Remove existing Chart.lock to force fresh resolution
    rm -f "${CHART_LOCK}"
    
    # Update dependencies
    helm dependency update .
    
    log_info "Chart.lock updated successfully."
}

# Build dependencies
build_deps() {
    log_info "Building dependencies..."
    
    cd "${ROOT_DIR}"
    
    helm dependency build .
    
    log_info "Dependencies built successfully."
}

# Validate chart
validate_chart() {
    log_info "Validating chart..."
    
    cd "${ROOT_DIR}"
    
    # Lint the chart
    if helm lint .; then
        log_info "Chart validation passed."
    else
        log_error "Chart validation failed."
        return 1
    fi
}

# Print usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
  --check     Check for available updates (default)
  --update    Update Chart.lock with current versions
  --all       Update dependencies and validate
  --help      Show this help message

Examples:
  $0                    # Check for updates
  $0 --update           # Update Chart.lock
  $0 --all              # Full update and validation
EOF
}

# Main execution
main() {
    local mode="check"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --check)
                mode="check"
                shift
                ;;
            --update)
                mode="update"
                shift
                ;;
            --all)
                mode="all"
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    check_helm
    add_repos
    
    case "${mode}" in
        check)
            check_updates
            ;;
        update)
            update_lock
            ;;
        all)
            update_lock
            build_deps
            validate_chart
            ;;
    esac
    
    log_info "Done!"
}

main "$@"
