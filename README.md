# k8s-observability-stack

[![Lint and Test](https://github.com/theorigamicorporation/k8s-observability-stack/actions/workflows/lint-test.yaml/badge.svg)](https://github.com/theorigamicorporation/k8s-observability-stack/actions/workflows/lint-test.yaml)
[![Release](https://github.com/theorigamicorporation/k8s-observability-stack/actions/workflows/release.yaml/badge.svg)](https://github.com/theorigamicorporation/k8s-observability-stack/actions/workflows/release.yaml)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

A complete, production-ready Kubernetes observability stack with VictoriaMetrics, Loki, Grafana Operator, and more. This chart serves as a modern replacement for `kube-prometheus-stack` and `kube-victoriametrics-stack` with enhanced support for larger clusters, service mesh integration, and distributed tracing.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture) | [Detailed Diagrams](docs/architecture.md)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Installation](#installation)
- [Configuration](#configuration)
- [Components](#components)
- [Upgrading](#upgrading)
- [Local Development](#local-development) | [Makefile Targets](#makefile-targets)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [Roadmap](#roadmap)
- [License](#license)

## Overview

The k8s-observability-stack is an umbrella Helm chart that deploys a complete observability solution for Kubernetes clusters. It integrates best-in-class open-source tools for metrics, logs, and traces collection, storage, and visualization.

### Why This Chart?

- **Unified Installation**: Deploy your entire observability stack with a single Helm chart
- **Production-Ready**: Pre-configured with best practices for alerting, dashboards, and retention
- **Scalable**: Support for both single-node and cluster modes for metrics and tracing backends
- **GitOps-Friendly**: Uses Grafana Operator for CRD-based management of datasources and dashboards
- **Auto-Configuration**: Automatic datasource and service connection setup based on enabled components

## Architecture

```mermaid
flowchart TB
    subgraph Sources["Data Sources"]
        K8S[("Kubernetes<br/>API Server")]
        PODS["Application<br/>Pods"]
        NODES["Cluster<br/>Nodes"]
    end

    subgraph Collection["Collection Layer"]
        ALLOY["Alloy<br/>(OTel Collector)"]
        KSM["kube-state-metrics<br/>(optional)"]
    end

    subgraph Storage["Storage Layer"]
        subgraph Metrics
            VM_SINGLE["VictoriaMetrics<br/>Single"]
            VM_CLUSTER["VictoriaMetrics<br/>Cluster"]
        end
        
        LOKI["Loki<br/>(Logs)"]
        
        subgraph Traces
            VT["VictoriaTraces"]
            JAEGER["Jaeger<br/>(optional)"]
        end
    end

    subgraph Alerting["Alerting Layer"]
        VMALERT["VMAlert<br/>(Rule Evaluation)"]
        AM["Alertmanager<br/>(optional)"]
    end

    subgraph Visualization["Visualization Layer"]
        GRAFANA_OP["Grafana<br/>Operator"]
        GRAFANA["Grafana<br/>Instance"]
        KIALI["Kiali<br/>(optional)"]
    end

    %% Data Collection Flows
    K8S -->|"metrics"| ALLOY
    PODS -->|"logs"| ALLOY
    PODS -->|"traces (OTLP)"| ALLOY
    NODES -->|"node metrics"| ALLOY
    K8S -->|"state"| KSM
    KSM -->|"metrics"| ALLOY

    %% Storage Flows
    ALLOY -->|"remote_write"| VM_SINGLE
    ALLOY -->|"remote_write"| VM_CLUSTER
    ALLOY -->|"push"| LOKI
    ALLOY -->|"OTLP"| VT
    ALLOY -->|"OTLP"| JAEGER

    %% Alerting Flows
    VM_SINGLE -->|"query"| VMALERT
    VM_CLUSTER -->|"query"| VMALERT
    VMALERT -->|"alerts"| AM

    %% Visualization Flows
    GRAFANA_OP -->|"manages"| GRAFANA
    VM_SINGLE -->|"datasource"| GRAFANA
    VM_CLUSTER -->|"datasource"| GRAFANA
    LOKI -->|"datasource"| GRAFANA
    VT -->|"datasource"| GRAFANA
    JAEGER -->|"datasource"| GRAFANA
    AM -->|"datasource"| GRAFANA
```

> **Note**: For detailed architecture diagrams including data flow, alert sequences, and component dependencies, see [docs/architecture.md](docs/architecture.md).

### Data Flow

1. **Metrics**: Alloy scrapes metrics from Kubernetes components and applications, forwards to VictoriaMetrics
2. **Logs**: Alloy collects container logs and forwards to Loki
3. **Traces**: Applications send traces via OTLP to Alloy, which forwards to VictoriaTraces or Jaeger
4. **Alerting**: VMAlert evaluates rules against VictoriaMetrics and sends alerts to Alertmanager
5. **Visualization**: Grafana queries all backends with auto-configured datasources

## Features

- **Metrics**
  - VictoriaMetrics for efficient time-series storage (single or cluster mode)
  - Pre-configured Kubernetes and node monitoring
  - Recording rules for optimized queries
  - Long-term retention support

- **Logs**
  - Loki for log aggregation
  - Automatic container log collection via Alloy
  - Log-to-trace correlation

- **Traces**
  - VictoriaTraces or Jaeger for distributed tracing
  - OTLP receiver support
  - Trace-to-log and trace-to-metrics correlation

- **Visualization**
  - Grafana Operator for CRD-based management
  - Auto-configured datasources
  - Pre-built dashboards from community mixins
  - Custom dashboard support

- **Alerting**
  - VMAlert for rule evaluation
  - Alertmanager for alert routing
  - Pre-configured Kubernetes alerts
  - Customizable alert rules

## Prerequisites

- Kubernetes 1.25+
- Helm 3.10+
- kubectl configured to access your cluster
- (Optional) For mixins: jsonnet-bundler (`jb`)

## Quick Start

```bash
# Add the Helm repository
helm repo add k8s-observability https://theorigamicorporation.github.io/k8s-observability-stack
helm repo update

# Install with default configuration
helm install observability k8s-observability/k8s-observability-stack \
  --namespace observability \
  --create-namespace

# Access Grafana
kubectl port-forward svc/observability-k8s-observability-stack-grafana-service 3000:3000 -n observability
# Open http://localhost:3000
```

## Installation

### Basic Installation

```bash
helm install observability k8s-observability/k8s-observability-stack \
  --namespace observability \
  --create-namespace
```

### Installation with Custom Values

```bash
# Create a values file
cat > my-values.yaml << EOF
global:
  clusterName: "production-cluster"

victoriametrics:
  mode: "cluster"  # Use cluster mode for production

alertmanager:
  enabled: true
  config:
    receivers:
      - name: 'slack'
        slack_configs:
          - channel: '#alerts'
            api_url: 'https://hooks.slack.com/services/xxx'

kube-state-metrics:
  enabled: true
EOF

# Install with custom values
helm install observability k8s-observability/k8s-observability-stack \
  -f my-values.yaml \
  --namespace observability \
  --create-namespace
```

### Production Installation

For production environments, consider:

```yaml
# production-values.yaml
global:
  clusterName: "production"
  storageClass: "fast-ssd"

victoriametrics:
  mode: "cluster"

vmcluster:
  vmselect:
    replicaCount: 3
  vminsert:
    replicaCount: 3
  vmstorage:
    replicaCount: 3
    persistentVolume:
      enabled: true
      size: 100Gi
    retentionPeriod: 90d

loki:
  deploymentMode: simple-scalable

alertmanager:
  enabled: true
  persistence:
    enabled: true
    size: 10Gi

kube-state-metrics:
  enabled: true
```

## Configuration

### Global Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.clusterName` | Cluster name for labeling | `""` |
| `global.storageClass` | Default storage class | `""` |
| `global.commonLabels` | Labels applied to all resources | `{}` |

### Component Toggles

| Parameter | Description | Default |
|-----------|-------------|---------|
| `grafana-operator.enabled` | Enable Grafana Operator | `true` |
| `grafana.instance.enabled` | Create Grafana instance | `true` |
| `loki.enabled` | Enable Loki | `true` |
| `alloy.enabled` | Enable Alloy collector | `true` |
| `victoriametrics.mode` | VM mode: "single" or "cluster" | `"single"` |
| `victoriatraces.enabled` | Enable VictoriaTraces | `false` |
| `alertmanager.enabled` | Enable Alertmanager | `false` |
| `jaeger.enabled` | Enable Jaeger | `false` |
| `kiali.enabled` | Enable Kiali | `false` |
| `kube-state-metrics.enabled` | Enable kube-state-metrics | `false` |

### VictoriaMetrics Configuration

```yaml
# Single mode (default, for small-medium clusters)
victoriametrics:
  mode: "single"

vmsingle:
  server:
    retentionPeriod: 14d
    persistentVolume:
      enabled: true
      size: 50Gi

# Cluster mode (for large clusters)
victoriametrics:
  mode: "cluster"

vmcluster:
  vmselect:
    replicaCount: 2
  vminsert:
    replicaCount: 2
  vmstorage:
    replicaCount: 2
    retentionPeriod: 30d
```

### Grafana Configuration

```yaml
grafana:
  instance:
    enabled: true
    ingress:
      enabled: true
      ingressClassName: nginx
      hosts:
        - grafana.example.com
      tls:
        - secretName: grafana-tls
          hosts:
            - grafana.example.com
  
  datasources:
    autoCreate: true
    additional:
      - name: external-prometheus
        type: prometheus
        url: http://prometheus.other-namespace:9090
```

### Full Configuration Reference

See [values.yaml](values.yaml) for all available configuration options.

## Components

### Core Components (Enabled by Default)

| Component | Description | Chart |
|-----------|-------------|-------|
| Grafana Operator | Manages Grafana instances via CRDs | [grafana-operator](https://artifacthub.io/packages/helm/grafana/grafana-operator) |
| Loki | Log aggregation system | [loki](https://artifacthub.io/packages/helm/grafana/loki) |
| Alloy | OpenTelemetry collector | [alloy](https://artifacthub.io/packages/helm/grafana/alloy) |
| VictoriaMetrics | Time-series database | [victoria-metrics-single](https://artifacthub.io/packages/helm/victoriametrics/victoria-metrics-single) |

### Optional Components (Disabled by Default)

| Component | Description | Chart |
|-----------|-------------|-------|
| kube-state-metrics | Kubernetes state exporter | [kube-state-metrics](https://artifacthub.io/packages/helm/bitnami/kube-state-metrics) |
| VictoriaTraces | Distributed tracing backend | [victoria-traces-single](https://artifacthub.io/packages/helm/victoriametrics/victoria-traces-single) |
| Alertmanager | Alert routing and management | [alertmanager](https://artifacthub.io/packages/helm/prometheus-community/alertmanager) |
| Jaeger | Distributed tracing (alternative) | [jaeger](https://artifacthub.io/packages/helm/jaegertracing/jaeger) |
| Kiali | Service mesh observability | [kiali-server](https://artifacthub.io/packages/helm/kiali/kiali-server) |

## Upgrading

### From v0.x to v0.y

```bash
# Check for breaking changes in release notes
# Backup your values
helm get values observability -n observability > backup-values.yaml

# Update repository
helm repo update

# Upgrade
helm upgrade observability k8s-observability/k8s-observability-stack \
  -f backup-values.yaml \
  --namespace observability
```

### Subchart Version Updates

The chart automatically tracks subchart updates. Major version changes may require value migrations. Check the changelog for breaking changes.

## Local Development

### Prerequisites

```bash
# Install required tools
brew install helm kubectl kind yq jq

# For mixin development
go install github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb@latest
go install github.com/google/go-jsonnet/cmd/jsonnet@latest
```

### Running Locally

Using the Makefile (recommended):

```bash
# One-command setup: create kind cluster, add repos, install chart
make dev

# Port-forward Grafana
make port-forward-grafana

# Cleanup when done
make dev-cleanup
```

Or manually:

```bash
# Create a kind cluster
kind create cluster --name observability-test

# Add Helm repositories
make add-repos

# Install with test values
make install VALUES_FILE=ci/test-values/default-values.yaml

# Port-forward Grafana
make port-forward-grafana
```

### Makefile Targets

```bash
make help              # Show all available targets

# Helm Operations
make install           # Install the chart
make upgrade           # Upgrade the release
make uninstall         # Uninstall the release
make dry-run           # Dry-run install with debug output
make status            # Show release status
make history           # Show release history
make rollback REVISION=1  # Rollback to specific revision
make get-values        # Get current release values
make get-manifest      # Get rendered manifests

# Development
make dev               # Full local dev setup with kind
make dev-cleanup       # Cleanup dev environment
make lint              # Lint the chart
make template          # Render templates
make test              # Run all tests

# Dependencies
make deps              # Update Helm dependencies
make add-repos         # Add required Helm repositories

# Mixins
make sync-mixins       # Install mixins and generate rules
make generate-rules    # Generate alert/recording rules

# Port Forwarding
make port-forward-grafana  # Forward Grafana to localhost:3000
make port-forward-vm       # Forward VictoriaMetrics to localhost:8428
```

Override defaults with environment variables:

```bash
make install RELEASE_NAME=my-stack NAMESPACE=monitoring VALUES_FILE=my-values.yaml
```

### Running Tests

```bash
# Run all tests (lint + template render)
make test

# Just lint
make lint

# Run chart-testing
make ct-lint
make ct-install

# Render templates to file
make template > rendered.yaml
```

### Updating Mixins

The chart uses a mixin-based approach similar to kube-prometheus-stack:

1. **Dashboards** are fetched from Grafana.com by ID (always up-to-date, no hardcoded JSON)
2. **Alert rules** can be generated from kubernetes-mixin and node-mixin
3. **VictoriaMetrics dashboards** are fetched from official VM repository URLs

```bash
# Install jsonnet dependencies
make mixins-install

# Generate alert/recording rules from mixins
make generate-rules

# Or do both at once
make sync-mixins
```

#### How Mixin Updates Work

- **Automatic**: Dashboards from Grafana.com update automatically (referenced by ID)
- **Manual**: Alert rules require regeneration when mixins update
- **CI Option**: The `update-deps.yaml` workflow can optionally update mixins

To customize mixin configuration, edit `mixins/config.libsonnet`:

```jsonnet
{
  _config+:: {
    // Change selectors to match your environment
    kubeStateMetricsSelector: 'job=~".*kube-state-metrics.*"',
    nodeExporterSelector: 'job="node-exporter"',
    
    // Adjust thresholds
    cpuUtilizationWarningThreshold: 0.75,
    memoryUtilizationWarningThreshold: 0.75,
  },
}
```

### Updating Dependencies

```bash
# Check for updates
./hack/update-deps.sh --check

# Update Chart.lock
./hack/update-deps.sh --update
```

## Troubleshooting

### Common Issues

#### Grafana not starting

```bash
# Check Grafana Operator logs
kubectl logs -l app.kubernetes.io/name=grafana-operator -n observability

# Check Grafana instance status
kubectl get grafana -n observability
kubectl describe grafana <name> -n observability
```

#### VictoriaMetrics not receiving metrics

```bash
# Check Alloy logs
kubectl logs -l app.kubernetes.io/name=alloy -n observability

# Verify remote write endpoint
kubectl exec -it deploy/alloy -n observability -- curl -s http://localhost:12345/metrics | grep remote_write
```

#### High memory usage in VictoriaMetrics

Consider switching to cluster mode:

```yaml
victoriametrics:
  mode: "cluster"

vmcluster:
  vmstorage:
    resources:
      limits:
        memory: 4Gi
```

#### Logs not appearing in Loki

```bash
# Check Alloy log collection
kubectl logs -l app.kubernetes.io/name=alloy -n observability | grep loki

# Verify Loki is receiving logs
kubectl exec -it deploy/loki -n observability -- wget -qO- http://localhost:3100/ready
```

### Debug Mode

Enable debug logging:

```yaml
alloy:
  alloy:
    extraArgs:
      - --log.level=debug

loki:
  loki:
    server:
      log_level: debug
```

### Getting Help

1. Check the [GitHub Issues](https://github.com/theorigamicorporation/k8s-observability-stack/issues)
2. Review component-specific documentation:
   - [VictoriaMetrics Docs](https://docs.victoriametrics.com/)
   - [Loki Docs](https://grafana.com/docs/loki/latest/)
   - [Grafana Operator Docs](https://grafana.github.io/grafana-operator/)

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Development Workflow

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests locally
5. Submit a pull request

### CI/CD

- **Lint and Test**: Runs on every PR and push to main/dev
- **Release**: Triggered on version tags (v*)
- **Dependency Updates**: Weekly automated PRs for subchart updates

## Roadmap

- [ ] Tempo support as alternative tracing backend
- [ ] OpenTelemetry Collector as alternative to Alloy
- [ ] Thanos integration for long-term storage
- [ ] Multi-cluster federation support
- [ ] Prometheus Operator compatibility mode
- [ ] Advanced mixin customization
- [ ] Helm chart testing with different Kubernetes distributions

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

---

**Maintained by [The Origami Corporation](https://github.com/theorigamicorporation)**
