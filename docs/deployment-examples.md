# Deployment Examples

This guide provides detailed examples for deploying `k8s-observability-stack` using GitOps tools.

## Table of Contents

- [Argo CD](#argo-cd)
  - [Application](#argo-cd-application)
  - [ApplicationSet](#argo-cd-applicationset)
  - [With Helm Values from Git](#argo-cd-with-helm-values-from-git)
- [Flux CD](#flux-cd)
  - [HelmRelease](#flux-helmrelease)
  - [With Kustomize Patches](#flux-with-kustomize-patches)
  - [Multi-Environment Setup](#flux-multi-environment-setup)

---

## Argo CD

### Argo CD Application

Basic Argo CD Application for deploying the observability stack:

```yaml
# argocd/observability-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: observability-stack
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  
  source:
    repoURL: https://theorigamicorporation.github.io/k8s-observability-stack
    chart: k8s-observability-stack
    targetRevision: 0.1.0
    helm:
      releaseName: observability
      values: |
        global:
          clusterName: "production"
        
        victoriametrics:
          mode: "single"
        
        alertmanager:
          enabled: true
        
        kube-state-metrics:
          enabled: true
  
  destination:
    server: https://kubernetes.default.svc
    namespace: observability
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

### Argo CD ApplicationSet

For multi-cluster deployments:

```yaml
# argocd/observability-appset.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: observability-stack
  namespace: argocd
spec:
  generators:
    - clusters:
        selector:
          matchLabels:
            observability: "enabled"
  
  template:
    metadata:
      name: 'observability-{{name}}'
    spec:
      project: default
      
      source:
        repoURL: https://theorigamicorporation.github.io/k8s-observability-stack
        chart: k8s-observability-stack
        targetRevision: 0.1.0
        helm:
          releaseName: observability
          values: |
            global:
              clusterName: "{{name}}"
            
            victoriametrics:
              mode: "{{metadata.labels.vm-mode}}"
      
      destination:
        server: '{{server}}'
        namespace: observability
      
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

### Argo CD with Helm Values from Git

Store your values in a Git repository for better version control:

```yaml
# argocd/observability-app-git-values.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: observability-stack
  namespace: argocd
spec:
  project: default
  
  sources:
    # Helm chart source
    - repoURL: https://theorigamicorporation.github.io/k8s-observability-stack
      chart: k8s-observability-stack
      targetRevision: 0.1.0
      helm:
        releaseName: observability
        valueFiles:
          - $values/clusters/production/observability-values.yaml
    
    # Values repository
    - repoURL: https://github.com/your-org/gitops-config.git
      targetRevision: main
      ref: values
  
  destination:
    server: https://kubernetes.default.svc
    namespace: observability
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

**Example values file in your gitops repo:**

```yaml
# gitops-config/clusters/production/observability-values.yaml
global:
  clusterName: "production"
  storageClass: "gp3"

victoriametrics:
  mode: "cluster"

vmcluster:
  vmselect:
    replicaCount: 3
    resources:
      requests:
        cpu: 500m
        memory: 512Mi
  vminsert:
    replicaCount: 3
  vmstorage:
    replicaCount: 3
    retentionPeriod: 90d
    persistentVolume:
      enabled: true
      size: 200Gi
      storageClassName: gp3

loki:
  deploymentMode: simple-scalable
  backend:
    replicas: 3
  read:
    replicas: 3
  write:
    replicas: 3

alertmanager:
  enabled: true
  config:
    receivers:
      - name: 'slack-critical'
        slack_configs:
          - api_url_file: /etc/alertmanager/secrets/slack-webhook
            channel: '#alerts-critical'
      - name: 'pagerduty'
        pagerduty_configs:
          - service_key_file: /etc/alertmanager/secrets/pagerduty-key

kube-state-metrics:
  enabled: true

grafana:
  instance:
    ingress:
      enabled: true
      ingressClassName: nginx
      annotations:
        cert-manager.io/cluster-issuer: letsencrypt-prod
      hosts:
        - grafana.example.com
      tls:
        - secretName: grafana-tls
          hosts:
            - grafana.example.com
```

---

## Flux CD

### Flux HelmRelease

Basic Flux HelmRelease for deploying the observability stack:

```yaml
# flux/observability/helmrepository.yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: k8s-observability
  namespace: flux-system
spec:
  interval: 1h
  url: https://theorigamicorporation.github.io/k8s-observability-stack
---
# flux/observability/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: observability
  labels:
    toolkit.fluxcd.io/tenant: platform
---
# flux/observability/helmrelease.yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: observability-stack
  namespace: observability
spec:
  interval: 30m
  chart:
    spec:
      chart: k8s-observability-stack
      version: "0.1.x"  # Semver range for automatic patch updates
      sourceRef:
        kind: HelmRepository
        name: k8s-observability
        namespace: flux-system
      interval: 1h
  
  install:
    crds: CreateReplace
    createNamespace: true
    remediation:
      retries: 3
  
  upgrade:
    crds: CreateReplace
    remediation:
      retries: 3
      remediateLastFailure: true
    cleanupOnFail: true
  
  values:
    global:
      clusterName: "production"
    
    victoriametrics:
      mode: "single"
    
    alertmanager:
      enabled: true
    
    kube-state-metrics:
      enabled: true
```

### Flux with Kustomize Patches

Use Kustomize for environment-specific overrides:

```yaml
# flux/base/observability/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
  - helmrepository.yaml
  - helmrelease.yaml
```

```yaml
# flux/base/observability/helmrelease.yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: observability-stack
  namespace: observability
spec:
  interval: 30m
  chart:
    spec:
      chart: k8s-observability-stack
      version: "0.1.x"
      sourceRef:
        kind: HelmRepository
        name: k8s-observability
        namespace: flux-system
  values:
    global:
      clusterName: ""  # Override per environment
    grafana-operator:
      enabled: true
    loki:
      enabled: true
    alloy:
      enabled: true
```

```yaml
# flux/clusters/production/observability/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../../base/observability
patches:
  - target:
      kind: HelmRelease
      name: observability-stack
    patch: |
      - op: replace
        path: /spec/values/global/clusterName
        value: "production"
      - op: add
        path: /spec/values/victoriametrics
        value:
          mode: "cluster"
      - op: add
        path: /spec/values/alertmanager
        value:
          enabled: true
      - op: add
        path: /spec/values/kube-state-metrics
        value:
          enabled: true
```

### Flux Multi-Environment Setup

Complete multi-environment structure:

```
flux/
├── base/
│   └── observability/
│       ├── kustomization.yaml
│       ├── namespace.yaml
│       ├── helmrepository.yaml
│       └── helmrelease.yaml
├── clusters/
│   ├── development/
│   │   ├── kustomization.yaml
│   │   └── observability/
│   │       ├── kustomization.yaml
│   │       └── values-patch.yaml
│   ├── staging/
│   │   ├── kustomization.yaml
│   │   └── observability/
│   │       ├── kustomization.yaml
│   │       └── values-patch.yaml
│   └── production/
│       ├── kustomization.yaml
│       └── observability/
│           ├── kustomization.yaml
│           └── values-patch.yaml
```

**Development values patch:**

```yaml
# flux/clusters/development/observability/values-patch.yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: observability-stack
  namespace: observability
spec:
  values:
    global:
      clusterName: "development"
    
    victoriametrics:
      mode: "single"
    
    vmsingle:
      server:
        retentionPeriod: 7d
        persistentVolume:
          enabled: true
          size: 20Gi
    
    loki:
      deploymentMode: monolithic
```

**Production values patch:**

```yaml
# flux/clusters/production/observability/values-patch.yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: observability-stack
  namespace: observability
spec:
  values:
    global:
      clusterName: "production"
      storageClass: "gp3-encrypted"
    
    victoriametrics:
      mode: "cluster"
    
    vmcluster:
      vmselect:
        replicaCount: 3
        resources:
          requests:
            cpu: 1
            memory: 1Gi
          limits:
            memory: 2Gi
      vminsert:
        replicaCount: 3
      vmstorage:
        replicaCount: 3
        retentionPeriod: 180d
        persistentVolume:
          enabled: true
          size: 500Gi
    
    loki:
      deploymentMode: simple-scalable
    
    alertmanager:
      enabled: true
      persistence:
        enabled: true
        size: 10Gi
    
    kube-state-metrics:
      enabled: true
    
    grafana:
      instance:
        ingress:
          enabled: true
          ingressClassName: nginx
          annotations:
            cert-manager.io/cluster-issuer: letsencrypt-prod
            nginx.ingress.kubernetes.io/ssl-redirect: "true"
          hosts:
            - grafana.prod.example.com
          tls:
            - secretName: grafana-prod-tls
              hosts:
                - grafana.prod.example.com
```

---

## External Secrets Integration

For both Argo CD and Flux, use External Secrets Operator for managing sensitive data:

```yaml
# external-secrets/grafana-admin-secret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: grafana-admin-credentials
  namespace: observability
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: aws-secrets-manager  # or vault, gcp, azure, etc.
  target:
    name: grafana-admin-credentials
    creationPolicy: Owner
  data:
    - secretKey: GF_SECURITY_ADMIN_USER
      remoteRef:
        key: observability/grafana
        property: admin-user
    - secretKey: GF_SECURITY_ADMIN_PASSWORD
      remoteRef:
        key: observability/grafana
        property: admin-password
```

Then reference in your values:

```yaml
grafana:
  existingSecret: grafana-admin-credentials
  adminUser: ""
  adminPassword: ""
```

---

## Useful Commands

### Argo CD

```bash
# Sync application
argocd app sync observability-stack

# Check application status
argocd app get observability-stack

# View application logs
argocd app logs observability-stack

# Diff against live state
argocd app diff observability-stack
```

### Flux CD

```bash
# Reconcile HelmRelease immediately
flux reconcile helmrelease observability-stack -n observability

# Check HelmRelease status
flux get helmrelease -n observability

# View Helm release history
helm history observability-stack -n observability

# Suspend/resume reconciliation
flux suspend helmrelease observability-stack -n observability
flux resume helmrelease observability-stack -n observability
```

---

## Best Practices

1. **Version Pinning**: Use specific versions in production, semver ranges in staging
2. **Secrets Management**: Never store secrets in Git; use External Secrets Operator or Sealed Secrets
3. **Resource Limits**: Always set resource requests/limits for production
4. **Health Checks**: Configure appropriate health checks in your GitOps tool
5. **Backup Values**: Keep a backup of your deployed values for disaster recovery
6. **Progressive Delivery**: Consider using Flagger or Argo Rollouts for canary deployments of dashboard changes

---

For more information, see the main [README](../README.md) or the [RUNBOOK](../RUNBOOK.md) for operational guidance.
