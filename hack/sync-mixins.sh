#!/usr/bin/env bash
# =============================================================================
# Sync Mixins Script
# =============================================================================
# This script downloads and synchronizes community mixins using jsonnet-bundler.
# It fetches:
# - kubernetes-mixin: Kubernetes dashboards and alerts
# - node-mixin: Node exporter dashboards and alerts
# - prometheus-mixin: Prometheus self-monitoring dashboards
#
# Usage: ./hack/sync-mixins.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
MIXINS_DIR="${ROOT_DIR}/mixins"
VENDOR_DIR="${MIXINS_DIR}/vendor"

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
    
    if ! command -v jb &> /dev/null; then
        log_error "jsonnet-bundler (jb) is not installed."
        log_info "Install it with: go install github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb@latest"
        exit 1
    fi
    
    if ! command -v jsonnet &> /dev/null; then
        log_error "jsonnet is not installed."
        log_info "Install it with: go install github.com/google/go-jsonnet/cmd/jsonnet@latest"
        exit 1
    fi
    
    if ! command -v gojsontoyaml &> /dev/null; then
        log_warn "gojsontoyaml is not installed. YAML output will not be available."
        log_info "Install it with: go install github.com/brancz/gojsontoyaml@latest"
    fi
    
    log_info "All required dependencies are installed."
}

# Initialize jsonnet-bundler if needed
init_jb() {
    log_info "Initializing jsonnet-bundler..."
    
    cd "${MIXINS_DIR}"
    
    if [[ ! -f "jsonnetfile.json" ]]; then
        log_info "Creating jsonnetfile.json..."
        cat > jsonnetfile.json << 'EOF'
{
  "version": 1,
  "dependencies": [
    {
      "source": {
        "git": {
          "remote": "https://github.com/kubernetes-monitoring/kubernetes-mixin.git",
          "subdir": ""
        }
      },
      "version": "master"
    },
    {
      "source": {
        "git": {
          "remote": "https://github.com/prometheus/node_exporter.git",
          "subdir": "docs/node-mixin"
        }
      },
      "version": "master"
    },
    {
      "source": {
        "git": {
          "remote": "https://github.com/prometheus/prometheus.git",
          "subdir": "documentation/prometheus-mixin"
        }
      },
      "version": "main"
    },
    {
      "source": {
        "git": {
          "remote": "https://github.com/grafana/grafonnet-lib.git",
          "subdir": "grafonnet"
        }
      },
      "version": "master"
    },
    {
      "source": {
        "git": {
          "remote": "https://github.com/grafana/jsonnet-libs.git",
          "subdir": "grafana-builder"
        }
      },
      "version": "master"
    }
  ],
  "legacyImports": true
}
EOF
    fi
}

# Update vendor dependencies
update_vendor() {
    log_info "Updating vendor dependencies..."
    
    cd "${MIXINS_DIR}"
    
    # Install/update dependencies
    jb install
    
    log_info "Vendor dependencies updated successfully."
}

# Create mixin configuration
create_mixin_config() {
    log_info "Creating mixin configuration..."
    
    cat > "${MIXINS_DIR}/config.libsonnet" << 'EOF'
// Mixin configuration for k8s-observability-stack
{
  _config+:: {
    // Kubernetes mixin config
    kubeStateMetricsSelector: 'job=~".*kube-state-metrics.*"',
    kubeletSelector: 'job="kubelet"',
    cadvisorSelector: 'job="kubelet"',
    nodeExporterSelector: 'job="node-exporter"',
    
    // Namespace for dashboards
    dashboardNamePrefix: 'K8s / ',
    dashboardTags: ['kubernetes', 'infra'],
    
    // Grafana datasource names
    datasourceName: 'VictoriaMetrics',
    lokiDatasourceName: 'Loki',
    
    // Alert configuration
    alertmanagerClusterLabels: 'cluster',
    alertmanagerNameLabels: 'namespace, pod',
    alertmanagerCriticalSlackChannel: '#alerts-critical',
    
    // Recording rules prefix
    recordingRulePrefix: '',
    
    // Pod disruption budget
    pdbEnabled: true,
    
    // Resource monitoring thresholds
    cpuThrottlingPercent: 25,
    cpuUtilizationWarningThreshold: 0.65,
    memoryUtilizationWarningThreshold: 0.65,
    
    // Node monitoring
    nodeHighMemoryUsageThreshold: 0.90,
    nodeHighCPUUsageThreshold: 0.90,
    
    // Disable specific alerts (if needed)
    // alertsToDisable: ['KubeMemoryOvercommit'],
  },
}
EOF
}

# Generate alerts
generate_alerts() {
    log_info "Generating alert rules..."
    
    cd "${MIXINS_DIR}"
    
    mkdir -p "${ROOT_DIR}/dashboards/alerts"
    
    cat > alerts.jsonnet << 'EOF'
local kubernetes = import 'kubernetes-mixin/mixin.libsonnet';
local nodeExporter = import 'node-mixin/mixin.libsonnet';
local config = import 'config.libsonnet';

{
  kubernetes: kubernetes {
    _config+:: config._config,
  }.prometheusAlerts,
  
  nodeExporter: nodeExporter {
    _config+:: config._config,
  }.prometheusAlerts,
}
EOF

    # Generate alerts as YAML
    jsonnet -J vendor alerts.jsonnet | \
        python3 -c "import sys, json; d=json.load(sys.stdin); [print('---\n' + json.dumps(v, indent=2)) for k, v in d.items()]" \
        > "${ROOT_DIR}/dashboards/alerts/mixin-alerts.json" 2>/dev/null || \
        jsonnet -J vendor alerts.jsonnet > "${ROOT_DIR}/dashboards/alerts/mixin-alerts.json"
    
    log_info "Alert rules generated at dashboards/alerts/mixin-alerts.json"
}

# Generate recording rules
generate_recording_rules() {
    log_info "Generating recording rules..."
    
    cd "${MIXINS_DIR}"
    
    mkdir -p "${ROOT_DIR}/dashboards/rules"
    
    cat > rules.jsonnet << 'EOF'
local kubernetes = import 'kubernetes-mixin/mixin.libsonnet';
local config = import 'config.libsonnet';

kubernetes {
  _config+:: config._config,
}.prometheusRules
EOF

    jsonnet -J vendor rules.jsonnet > "${ROOT_DIR}/dashboards/rules/mixin-rules.json"
    
    log_info "Recording rules generated at dashboards/rules/mixin-rules.json"
}

# Main execution
main() {
    log_info "Starting mixin synchronization..."
    
    # Create mixins directory if it doesn't exist
    mkdir -p "${MIXINS_DIR}"
    
    check_dependencies
    init_jb
    update_vendor
    create_mixin_config
    generate_alerts
    generate_recording_rules
    
    log_info "Mixin synchronization completed successfully!"
    log_info ""
    log_info "Next steps:"
    log_info "  1. Run ./hack/generate-dashboards.sh to generate Grafana dashboards"
    log_info "  2. Commit the generated files"
}

main "$@"
