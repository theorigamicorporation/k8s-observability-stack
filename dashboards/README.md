# Generated Dashboards

This directory contains dashboards generated from community mixins.

## Directory Structure

- `kubernetes/` - Kubernetes monitoring dashboards (from kubernetes-mixin)
- `node-exporter/` - Node exporter dashboards (from node-mixin)
- `victoriametrics/` - VictoriaMetrics official dashboards
- `loki/` - Loki dashboards

## Regenerating Dashboards

To regenerate these dashboards:

```bash
# First, sync the mixins
./hack/sync-mixins.sh

# Then generate dashboards
./hack/generate-dashboards.sh
```

## Dashboard List

- `kubernetes/apiserver.json`
- `kubernetes/cluster-total.json`
- `kubernetes/controller-manager.json`
- `kubernetes/k8s-resources-cluster.json`
- `kubernetes/k8s-resources-namespace.json`
- `kubernetes/k8s-resources-node.json`
- `kubernetes/k8s-resources-pod.json`
- `kubernetes/k8s-resources-windows-cluster.json`
- `kubernetes/k8s-resources-windows-namespace.json`
- `kubernetes/k8s-resources-windows-pod.json`
- `kubernetes/k8s-resources-workload.json`
- `kubernetes/k8s-resources-workloads-namespace.json`
- `kubernetes/k8s-windows-cluster-rsrc-use.json`
- `kubernetes/k8s-windows-node-rsrc-use.json`
- `kubernetes/kubelet.json`
- `kubernetes/namespace-by-pod.json`
- `kubernetes/namespace-by-workload.json`
- `kubernetes/persistentvolumesusage.json`
- `kubernetes/pod-total.json`
- `kubernetes/proxy.json`
- `kubernetes/scheduler.json`
- `kubernetes/workload-total.json`
- `loki/loki-logs.json`
- `loki/loki-operational.json`
- `node-exporter/node-cluster-rsrc-use.json`
- `node-exporter/node-rsrc-use.json`
- `node-exporter/nodes-aix.json`
- `node-exporter/nodes-darwin.json`
- `node-exporter/nodes.json`
- `victoriametrics/victoriametrics.json`
- `victoriametrics/vmagent.json`
- `victoriametrics/vmalert.json`
