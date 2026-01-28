#!/usr/bin/env bash
# =============================================================================
# Refresh External Subchart Values
# =============================================================================
# Downloads the latest values.yaml from all subchart dependencies.
# These files are for reference only and are gitignored.
#
# Usage: ./hack/refresh-external-values.sh
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT_DIR="${REPO_ROOT}/external-values"

echo -e "${GREEN}=== Refreshing External Subchart Values ===${NC}"
echo "Output directory: ${OUTPUT_DIR}"
echo ""

# Create output directory
mkdir -p "${OUTPUT_DIR}"

# Add/update helm repositories
echo -e "${YELLOW}Adding Helm repositories...${NC}"
helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
helm repo add victoriametrics https://victoriametrics.github.io/helm-charts 2>/dev/null || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null || true
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts 2>/dev/null || true
helm repo add kiali https://kiali.org/helm-charts 2>/dev/null || true

echo -e "${YELLOW}Updating Helm repositories...${NC}"
helm repo update

echo ""
echo -e "${YELLOW}Downloading subchart values...${NC}"

# Define charts to download
# Format: "repo/chart:output-filename"
CHARTS=(
    "grafana/grafana-operator:grafana-operator"
    "grafana/loki:loki"
    "grafana/alloy:alloy"
    "victoriametrics/victoria-metrics-single:vmsingle"
    "victoriametrics/victoria-metrics-cluster:vmcluster"
    "bitnami/kube-state-metrics:kube-state-metrics"
    "victoriametrics/victoria-traces-single:vtsingle"
    "victoriametrics/victoria-traces-cluster:vtcluster"
    "prometheus-community/alertmanager:alertmanager"
    "jaegertracing/jaeger:jaeger"
    "kiali/kiali-server:kiali-server"
)

# Download each chart's values
FAILED=()
for chart_spec in "${CHARTS[@]}"; do
    chart="${chart_spec%%:*}"
    output_name="${chart_spec##*:}"
    output_file="${OUTPUT_DIR}/${output_name}.yaml"
    
    echo -n "  Downloading ${chart}... "
    if helm show values "${chart}" > "${output_file}" 2>/dev/null; then
        lines=$(wc -l < "${output_file}")
        echo -e "${GREEN}OK${NC} (${lines} lines)"
    else
        echo -e "${RED}FAILED${NC}"
        FAILED+=("${chart}")
        rm -f "${output_file}"
    fi
done

echo ""

# Summary
if [ ${#FAILED[@]} -eq 0 ]; then
    echo -e "${GREEN}=== All subchart values downloaded successfully ===${NC}"
else
    echo -e "${RED}=== Some downloads failed ===${NC}"
    for chart in "${FAILED[@]}"; do
        echo -e "  ${RED}✗${NC} ${chart}"
    done
    exit 1
fi

# Show file sizes
echo ""
echo "Downloaded files:"
ls -lh "${OUTPUT_DIR}"/*.yaml 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'

echo ""
echo -e "${GREEN}Done!${NC} Files saved to: ${OUTPUT_DIR}/"
echo "Note: These files are gitignored and for reference only."
