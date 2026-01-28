# Architecture

## Component Overview

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

    %% Styling
    classDef core fill:#2d6a4f,stroke:#1b4332,color:#fff
    classDef optional fill:#6c757d,stroke:#495057,color:#fff
    classDef storage fill:#0077b6,stroke:#023e8a,color:#fff
    classDef alert fill:#dc3545,stroke:#bd2130,color:#fff
    classDef viz fill:#6f42c1,stroke:#563d7c,color:#fff

    class ALLOY,LOKI core
    class VM_SINGLE,VM_CLUSTER,VT storage
    class KSM,JAEGER,AM,KIALI optional
    class VMALERT alert
    class GRAFANA_OP,GRAFANA viz
```

## Data Flow Diagram

```mermaid
flowchart LR
    subgraph Ingestion["Ingestion"]
        M["Metrics"]
        L["Logs"]
        T["Traces"]
    end

    subgraph Processing["Alloy Processing"]
        direction TB
        SCRAPE["Prometheus<br/>Scrape"]
        LOGSRC["Log<br/>Collection"]
        OTLP["OTLP<br/>Receiver"]
        RELABEL["Relabeling &<br/>Processing"]
    end

    subgraph Backends["Backends"]
        VM["VictoriaMetrics"]
        LOKI["Loki"]
        VT["VictoriaTraces"]
    end

    subgraph Query["Query & Viz"]
        G["Grafana"]
    end

    M --> SCRAPE
    L --> LOGSRC
    T --> OTLP
    
    SCRAPE --> RELABEL
    LOGSRC --> RELABEL
    OTLP --> RELABEL
    
    RELABEL -->|"remote_write"| VM
    RELABEL -->|"loki.write"| LOKI
    RELABEL -->|"otelcol.exporter"| VT
    
    VM --> G
    LOKI --> G
    VT --> G
```

## VictoriaMetrics Mode Selection

```mermaid
flowchart TB
    START["victoriametrics.mode"]
    
    START -->|"single"| SINGLE["VictoriaMetrics Single<br/>(vmsingle)"]
    START -->|"cluster"| CLUSTER["VictoriaMetrics Cluster<br/>(vmcluster)"]
    
    SINGLE -->|"Small/Medium<br/>Clusters"| SINGLE_USE["• Up to 1M active series<br/>• Simple deployment<br/>• Single replica"]
    
    CLUSTER -->|"Large<br/>Clusters"| CLUSTER_COMP["vminsert<br/>vmselect<br/>vmstorage"]
    CLUSTER_COMP --> CLUSTER_USE["• Horizontal scaling<br/>• High availability<br/>• Multi-tenant"]
    
    classDef default fill:#f8f9fa,stroke:#dee2e6,color:#212529
    classDef highlight fill:#0077b6,stroke:#023e8a,color:#fff
    
    class SINGLE,CLUSTER highlight
```

## Alert Flow

```mermaid
sequenceDiagram
    participant VM as VictoriaMetrics
    participant VA as VMAlert
    participant AM as Alertmanager
    participant R as Receiver<br/>(Slack/Email/etc)
    
    loop Every evaluation interval
        VA->>VM: Query alert rules
        VM-->>VA: Return metrics data
        VA->>VA: Evaluate rules
        alt Alert firing
            VA->>AM: Send alert
            AM->>AM: Group & dedupe
            AM->>R: Route notification
        end
    end
```

## Component Dependencies

```mermaid
graph TD
    subgraph Always["Always Enabled"]
        GO["grafana-operator"]
        GI["Grafana Instance"]
        LOKI["Loki"]
        ALLOY["Alloy"]
        VM["VictoriaMetrics<br/>(single or cluster)"]
    end
    
    subgraph Optional["Optional Components"]
        KSM["kube-state-metrics"]
        VT["VictoriaTraces"]
        AM["Alertmanager"]
        JAEGER["Jaeger"]
        KIALI["Kiali"]
    end
    
    GO --> GI
    VM --> GI
    LOKI --> GI
    VT --> GI
    JAEGER --> GI
    AM --> GI
    
    ALLOY --> VM
    ALLOY --> LOKI
    ALLOY --> VT
    ALLOY --> JAEGER
    
    KSM --> ALLOY
    
    classDef core fill:#2d6a4f,stroke:#1b4332,color:#fff
    classDef optional fill:#6c757d,stroke:#495057,color:#fff
    
    class GO,GI,LOKI,ALLOY,VM core
    class KSM,VT,AM,JAEGER,KIALI optional
```

## Network Ports

| Component | Port | Protocol | Description |
|-----------|------|----------|-------------|
| Grafana | 3000 | HTTP | Web UI |
| VictoriaMetrics Single | 8428 | HTTP | Query/Write API |
| VictoriaMetrics vmselect | 8481 | HTTP | Query API |
| VictoriaMetrics vminsert | 8480 | HTTP | Write API |
| Loki | 3100 | HTTP | Query/Push API |
| Alloy | 12345 | HTTP | UI/Metrics |
| Alloy | 4317 | gRPC | OTLP gRPC |
| Alloy | 4318 | HTTP | OTLP HTTP |
| Alertmanager | 9093 | HTTP | Web UI/API |
| Jaeger Query | 16686 | HTTP | Web UI |
| Kiali | 20001 | HTTP | Web UI |
