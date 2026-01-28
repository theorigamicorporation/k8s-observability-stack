// =============================================================================
// Mixin Configuration for k8s-observability-stack
// =============================================================================
// This file configures the community mixins (kubernetes-mixin, node-mixin)
// for dashboard and alert rule generation.
//
// To customize, edit this file and run: make sync-mixins
// =============================================================================

{
  _config+:: {
    // =========================================================================
    // Kubernetes Mixin Configuration
    // =========================================================================
    
    // Selector for kube-state-metrics
    kubeStateMetricsSelector: 'job=~".*kube-state-metrics.*"',
    
    // Selector for kubelet metrics
    kubeletSelector: 'job="kubelet"',
    
    // Selector for cAdvisor metrics (usually same as kubelet)
    cadvisorSelector: 'job="kubelet"',
    
    // Selector for node-exporter
    nodeExporterSelector: 'job="node-exporter"',
    
    // Selector for API server metrics
    kubeApiserverSelector: 'job="kubernetes-apiserver"',
    
    // Selector for scheduler metrics
    kubeSchedulerSelector: 'job="kube-scheduler"',
    
    // Selector for controller-manager metrics
    kubeControllerManagerSelector: 'job="kube-controller-manager"',
    
    // =========================================================================
    // Dashboard Configuration
    // =========================================================================
    
    // Prefix for dashboard titles
    dashboardNamePrefix: 'K8s / ',
    
    // Tags applied to all dashboards
    dashboardTags: ['kubernetes', 'infra'],
    
    // Grafana datasource names
    datasourceName: 'VictoriaMetrics',
    lokiDatasourceName: 'Loki',
    
    // =========================================================================
    // Alert Configuration
    // =========================================================================
    
    // Labels used for alert grouping
    alertmanagerClusterLabels: 'cluster',
    alertmanagerNameLabels: 'namespace, pod',
    
    // Critical alert Slack channel (if using Slack)
    alertmanagerCriticalSlackChannel: '#alerts-critical',
    
    // Recording rules prefix (usually empty)
    recordingRulePrefix: '',
    
    // =========================================================================
    // Resource Thresholds
    // =========================================================================
    
    // CPU throttling threshold (percentage)
    cpuThrottlingPercent: 25,
    
    // CPU utilization warning threshold (0-1)
    cpuUtilizationWarningThreshold: 0.65,
    
    // Memory utilization warning threshold (0-1)  
    memoryUtilizationWarningThreshold: 0.65,
    
    // Node high memory usage threshold (0-1)
    nodeHighMemoryUsageThreshold: 0.90,
    
    // Node high CPU usage threshold (0-1)
    nodeHighCPUUsageThreshold: 0.90,
    
    // =========================================================================
    // Feature Toggles
    // =========================================================================
    
    // Enable Pod Disruption Budget monitoring
    pdbEnabled: true,
    
    // Show multi-cluster dashboards
    showMultiCluster: false,
    
    // Runbook URL prefix for alert annotations
    runbookURLPattern: 'https://runbooks.prometheus-operator.dev/runbooks/%s/%s',
    
    // =========================================================================
    // Alerts to Disable
    // =========================================================================
    // Uncomment to disable specific alerts
    // alertsToDisable: [
    //   'KubeMemoryOvercommit',
    //   'KubeCPUOvercommit',
    // ],
  },
}
