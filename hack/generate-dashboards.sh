#!/usr/bin/env bash
# =============================================================================
# Generate Dashboards Script
# =============================================================================
# This script generates Grafana dashboards from community mixins.
# It creates dashboard JSON files that can be imported into Grafana or
# converted to GrafanaDashboard CRDs.
#
# Usage: ./hack/generate-dashboards.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
MIXINS_DIR="${ROOT_DIR}/mixins"
DASHBOARDS_DIR="${ROOT_DIR}/dashboards"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check dependencies
check_dependencies() {
    log_info "Checking dependencies..."
    
    if ! command -v jsonnet &> /dev/null; then
        log_error "jsonnet is not installed."
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed."
        exit 1
    fi
    
    log_info "Dependencies check passed."
}

# Create dashboards directory structure
setup_directories() {
    log_info "Setting up directories..."
    
    mkdir -p "${DASHBOARDS_DIR}/kubernetes"
    mkdir -p "${DASHBOARDS_DIR}/node-exporter"
    mkdir -p "${DASHBOARDS_DIR}/victoriametrics"
    mkdir -p "${DASHBOARDS_DIR}/loki"
}

# Generate Kubernetes dashboards from mixin
generate_kubernetes_dashboards() {
    log_info "Generating Kubernetes dashboards..."
    
    cd "${MIXINS_DIR}"
    
    if [[ ! -d "vendor/kubernetes-mixin" ]]; then
        log_warn "kubernetes-mixin not found. Run sync-mixins.sh first."
        return
    fi
    
    cat > dashboards.jsonnet << 'EOF'
local kubernetes = import 'kubernetes-mixin/mixin.libsonnet';
local config = import 'config.libsonnet';

kubernetes {
  _config+:: config._config,
}.grafanaDashboards
EOF

    # Generate each dashboard as a separate file
    jsonnet -J vendor dashboards.jsonnet | jq -r 'to_entries[] | @base64' | while read -r entry; do
        name=$(echo "${entry}" | base64 -d | jq -r '.key' | sed 's/\.json$//')
        dashboard=$(echo "${entry}" | base64 -d | jq '.value')
        
        # Sanitize filename
        filename=$(echo "${name}" | tr '/' '-' | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
        
        echo "${dashboard}" | jq '.' > "${DASHBOARDS_DIR}/kubernetes/${filename}.json"
        log_info "  Generated: kubernetes/${filename}.json"
    done
    
    log_info "Kubernetes dashboards generated successfully."
}

# Generate Node Exporter dashboards
generate_node_dashboards() {
    log_info "Generating Node Exporter dashboards..."
    
    cd "${MIXINS_DIR}"
    
    if [[ ! -d "vendor/node-mixin" ]]; then
        log_warn "node-mixin not found. Run sync-mixins.sh first."
        return
    fi
    
    cat > node-dashboards.jsonnet << 'EOF'
local nodeExporter = import 'node-mixin/mixin.libsonnet';
local config = import 'config.libsonnet';

nodeExporter {
  _config+:: config._config,
}.grafanaDashboards
EOF

    jsonnet -J vendor node-dashboards.jsonnet | jq -r 'to_entries[] | @base64' | while read -r entry; do
        name=$(echo "${entry}" | base64 -d | jq -r '.key' | sed 's/\.json$//')
        dashboard=$(echo "${entry}" | base64 -d | jq '.value')
        
        filename=$(echo "${name}" | tr '/' '-' | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
        
        echo "${dashboard}" | jq '.' > "${DASHBOARDS_DIR}/node-exporter/${filename}.json"
        log_info "  Generated: node-exporter/${filename}.json"
    done
    
    log_info "Node Exporter dashboards generated successfully."
}

# Download VictoriaMetrics official dashboards
download_vm_dashboards() {
    log_info "Downloading VictoriaMetrics dashboards..."
    
    local vm_dashboards=(
        "https://raw.githubusercontent.com/VictoriaMetrics/VictoriaMetrics/master/dashboards/victoriametrics.json"
        "https://raw.githubusercontent.com/VictoriaMetrics/VictoriaMetrics/master/dashboards/vmagent.json"
        "https://raw.githubusercontent.com/VictoriaMetrics/VictoriaMetrics/master/dashboards/vmalert.json"
    )
    
    for url in "${vm_dashboards[@]}"; do
        filename=$(basename "${url}")
        if curl -sL "${url}" -o "${DASHBOARDS_DIR}/victoriametrics/${filename}"; then
            log_info "  Downloaded: victoriametrics/${filename}"
        else
            log_warn "  Failed to download: ${url}"
        fi
    done
    
    log_info "VictoriaMetrics dashboards downloaded."
}

# Download Loki dashboards
download_loki_dashboards() {
    log_info "Downloading Loki dashboards..."
    
    local loki_dashboards=(
        "https://raw.githubusercontent.com/grafana/loki/main/production/loki-mixin-compiled/dashboards/loki-logs.json"
        "https://raw.githubusercontent.com/grafana/loki/main/production/loki-mixin-compiled/dashboards/loki-operational.json"
    )
    
    for url in "${loki_dashboards[@]}"; do
        filename=$(basename "${url}")
        if curl -sL "${url}" -o "${DASHBOARDS_DIR}/loki/${filename}"; then
            log_info "  Downloaded: loki/${filename}"
        else
            log_warn "  Failed to download: ${url}"
        fi
    done
    
    log_info "Loki dashboards downloaded."
}

# Generate dashboard ConfigMaps for Helm
generate_configmaps() {
    log_info "Generating dashboard ConfigMaps..."
    
    local output_file="${ROOT_DIR}/templates/grafana/dashboard-configmaps.yaml"
    
    cat > "${output_file}" << 'EOF'
{{- if and (index .Values "grafana-operator" "enabled") .Values.grafana.instance.enabled .Values.grafana.dashboards.enabled }}
{{/*
Dashboard ConfigMaps generated from mixins
These are created by hack/generate-dashboards.sh
*/}}
EOF

    # Find all dashboard JSON files
    find "${DASHBOARDS_DIR}" -name "*.json" -type f | while read -r dashboard_file; do
        local relative_path="${dashboard_file#${DASHBOARDS_DIR}/}"
        local category=$(dirname "${relative_path}")
        local filename=$(basename "${dashboard_file}" .json)
        local safe_name=$(echo "${filename}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')
        
        cat >> "${output_file}" << EOF
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "k8s-observability-stack.dashboardPrefix" . }}-${safe_name}
  namespace: {{ include "k8s-observability-stack.namespace" . }}
  labels:
    {{- include "k8s-observability-stack.labels" . | nindent 4 }}
    app.kubernetes.io/component: grafana-dashboard
    dashboard-category: ${category}
data:
  ${filename}.json: |
EOF
        # Indent the JSON content
        sed 's/^/    /' "${dashboard_file}" >> "${output_file}"
        echo "" >> "${output_file}"
    done
    
    echo '{{- end }}' >> "${output_file}"
    
    log_info "Dashboard ConfigMaps generated at templates/grafana/dashboard-configmaps.yaml"
}

# Create index file
create_index() {
    log_info "Creating dashboard index..."
    
    cat > "${DASHBOARDS_DIR}/README.md" << EOF
# Generated Dashboards

This directory contains dashboards generated from community mixins.

## Directory Structure

- \`kubernetes/\` - Kubernetes monitoring dashboards (from kubernetes-mixin)
- \`node-exporter/\` - Node exporter dashboards (from node-mixin)
- \`victoriametrics/\` - VictoriaMetrics official dashboards
- \`loki/\` - Loki dashboards

## Regenerating Dashboards

To regenerate these dashboards:

\`\`\`bash
# First, sync the mixins
./hack/sync-mixins.sh

# Then generate dashboards
./hack/generate-dashboards.sh
\`\`\`

## Dashboard List

EOF

    # List all dashboards
    find "${DASHBOARDS_DIR}" -name "*.json" -type f | sort | while read -r dashboard; do
        local relative="${dashboard#${DASHBOARDS_DIR}/}"
        echo "- \`${relative}\`" >> "${DASHBOARDS_DIR}/README.md"
    done
    
    log_info "Dashboard index created at dashboards/README.md"
}

# Main execution
main() {
    log_info "Starting dashboard generation..."
    
    check_dependencies
    setup_directories
    
    # Generate from mixins (if available)
    if [[ -d "${MIXINS_DIR}/vendor" ]]; then
        generate_kubernetes_dashboards
        generate_node_dashboards
    else
        log_warn "Mixin vendor directory not found. Run ./hack/sync-mixins.sh first."
        log_info "Proceeding with dashboard downloads only..."
    fi
    
    # Download official dashboards
    download_vm_dashboards
    download_loki_dashboards
    
    # Generate Helm resources
    generate_configmaps
    
    # Create index
    create_index
    
    log_info ""
    log_info "Dashboard generation completed!"
    log_info "Generated dashboards are in: ${DASHBOARDS_DIR}"
}

main "$@"
