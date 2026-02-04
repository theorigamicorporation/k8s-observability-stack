{{/*
Expand the name of the chart.
*/}}
{{- define "k8s-observability-stack.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "k8s-observability-stack.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "k8s-observability-stack.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "k8s-observability-stack.labels" -}}
helm.sh/chart: {{ include "k8s-observability-stack.chart" . }}
{{ include "k8s-observability-stack.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.global.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "k8s-observability-stack.selectorLabels" -}}
app.kubernetes.io/name: {{ include "k8s-observability-stack.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Common annotations
*/}}
{{- define "k8s-observability-stack.annotations" -}}
{{- with .Values.global.commonAnnotations }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "k8s-observability-stack.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "k8s-observability-stack.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/* ==========================================================================
   VictoriaMetrics Mode Helpers
   ========================================================================== */}}

{{/*
Determine if VictoriaMetrics single mode is enabled
*/}}
{{- define "k8s-observability-stack.vmSingleEnabled" -}}
{{- if eq .Values.victoriametrics.mode "single" -}}
true
{{- else -}}
false
{{- end -}}
{{- end }}

{{/*
Determine if VictoriaMetrics cluster mode is enabled
*/}}
{{- define "k8s-observability-stack.vmClusterEnabled" -}}
{{- if eq .Values.victoriametrics.mode "cluster" -}}
true
{{- else -}}
false
{{- end -}}
{{- end }}

{{/*
Get VictoriaMetrics write URL based on mode
*/}}
{{- define "k8s-observability-stack.vmWriteUrl" -}}
{{- if eq .Values.victoriametrics.mode "cluster" -}}
http://{{ include "k8s-observability-stack.fullname" . }}-vmcluster-vminsert:8480/insert/0/prometheus/api/v1/write
{{- else -}}
http://{{ include "k8s-observability-stack.fullname" . }}-vmsingle-server:8428/api/v1/write
{{- end -}}
{{- end }}

{{/*
Get VictoriaMetrics read/query URL based on mode
*/}}
{{- define "k8s-observability-stack.vmQueryUrl" -}}
{{- if eq .Values.victoriametrics.mode "cluster" -}}
http://{{ include "k8s-observability-stack.fullname" . }}-vmcluster-vmselect:8481/select/0/prometheus
{{- else -}}
http://{{ include "k8s-observability-stack.fullname" . }}-vmsingle-server:8428
{{- end -}}
{{- end }}

{{/* ==========================================================================
   VictoriaTraces Mode Helpers
   ========================================================================== */}}

{{/*
Determine if VictoriaTraces is enabled (any mode)
*/}}
{{- define "k8s-observability-stack.vtEnabled" -}}
{{- if .Values.victoriatraces.enabled -}}
true
{{- else -}}
false
{{- end -}}
{{- end }}

{{/*
Determine if VictoriaTraces single mode is enabled
*/}}
{{- define "k8s-observability-stack.vtSingleEnabled" -}}
{{- if and .Values.victoriatraces.enabled (eq .Values.victoriatraces.mode "single") -}}
true
{{- else -}}
false
{{- end -}}
{{- end }}

{{/*
Determine if VictoriaTraces cluster mode is enabled
*/}}
{{- define "k8s-observability-stack.vtClusterEnabled" -}}
{{- if and .Values.victoriatraces.enabled (eq .Values.victoriatraces.mode "cluster") -}}
true
{{- else -}}
false
{{- end -}}
{{- end }}

{{/*
Get VictoriaTraces URL based on mode
*/}}
{{- define "k8s-observability-stack.vtUrl" -}}
{{- if eq .Values.victoriatraces.mode "cluster" -}}
http://{{ include "k8s-observability-stack.fullname" . }}-vtcluster:9411
{{- else -}}
http://{{ include "k8s-observability-stack.fullname" . }}-vtsingle-server:9411
{{- end -}}
{{- end }}

{{/* ==========================================================================
   Service URL Helpers
   ========================================================================== */}}

{{/*
Get Loki URL
*/}}
{{- define "k8s-observability-stack.lokiUrl" -}}
{{- if .Values.grafana.datasources.loki.url -}}
{{ .Values.grafana.datasources.loki.url }}
{{- else -}}
http://{{ .Release.Name }}-loki:3100
{{- end -}}
{{- end }}

{{/*
Get Grafana URL
*/}}
{{- define "k8s-observability-stack.grafanaUrl" -}}
http://{{ include "k8s-observability-stack.fullname" . }}-grafana:3000
{{- end }}

{{/*
Get Alertmanager URL
*/}}
{{- define "k8s-observability-stack.alertmanagerUrl" -}}
{{- if .Values.alertmanager.enabled -}}
http://{{ include "k8s-observability-stack.fullname" . }}-alertmanager:9093
{{- else -}}
""
{{- end -}}
{{- end }}

{{/*
Get Jaeger URL
*/}}
{{- define "k8s-observability-stack.jaegerUrl" -}}
{{- if .Values.jaeger.enabled -}}
http://{{ include "k8s-observability-stack.fullname" . }}-jaeger-query:16686
{{- else -}}
""
{{- end -}}
{{- end }}

{{/*
Get tracing URL (VictoriaTraces or Jaeger, depending on what's enabled)
*/}}
{{- define "k8s-observability-stack.tracingUrl" -}}
{{- if .Values.grafana.datasources.tracing.url -}}
{{ .Values.grafana.datasources.tracing.url }}
{{- else if .Values.victoriatraces.enabled -}}
{{ include "k8s-observability-stack.vtUrl" . }}
{{- else if .Values.jaeger.enabled -}}
{{ include "k8s-observability-stack.jaegerUrl" . }}
{{- else -}}
""
{{- end -}}
{{- end }}

{{/*
Get kube-state-metrics URL
*/}}
{{- define "k8s-observability-stack.ksmUrl" -}}
{{- if index .Values "kube-state-metrics" "enabled" -}}
http://{{ include "k8s-observability-stack.fullname" . }}-kube-state-metrics:8080
{{- else -}}
""
{{- end -}}
{{- end }}

{{/* ==========================================================================
   Grafana Operator Helpers
   ========================================================================== */}}

{{/*
Grafana instance name
*/}}
{{- define "k8s-observability-stack.grafanaInstanceName" -}}
{{ include "k8s-observability-stack.fullname" . }}-grafana
{{- end }}

{{/*
Grafana admin secret name
*/}}
{{- define "k8s-observability-stack.grafanaAdminSecretName" -}}
{{ include "k8s-observability-stack.fullname" . }}-grafana-admin
{{- end }}

{{/* ==========================================================================
   Component Name Helpers
   ========================================================================== */}}

{{/*
VMAlert name
*/}}
{{- define "k8s-observability-stack.vmalertName" -}}
{{ include "k8s-observability-stack.fullname" . }}-vmalert
{{- end }}

{{/*
Alloy ConfigMap name
*/}}
{{- define "k8s-observability-stack.alloyConfigName" -}}
{{ include "k8s-observability-stack.fullname" . }}-alloy-config
{{- end }}

{{/* ==========================================================================
   Conditional Logic Helpers
   ========================================================================== */}}

{{/*
Check if any tracing backend is enabled
*/}}
{{- define "k8s-observability-stack.tracingEnabled" -}}
{{- if or .Values.victoriatraces.enabled .Values.jaeger.enabled -}}
true
{{- else -}}
false
{{- end -}}
{{- end }}

{{/*
Check if alerting is enabled (Alertmanager or vmalert)
*/}}
{{- define "k8s-observability-stack.alertingEnabled" -}}
{{- if or .Values.alertmanager.enabled .Values.vmalert.enabled -}}
true
{{- else -}}
false
{{- end -}}
{{- end }}

{{/*
Check if mixins are enabled
*/}}
{{- define "k8s-observability-stack.mixinsEnabled" -}}
{{- if .Values.mixins.enabled -}}
true
{{- else -}}
false
{{- end -}}
{{- end }}

{{/* ==========================================================================
   Resource Naming Helpers
   ========================================================================== */}}

{{/*
VMRule name prefix
*/}}
{{- define "k8s-observability-stack.vmrulePrefix" -}}
{{ include "k8s-observability-stack.fullname" . }}-vmrule
{{- end }}

{{/*
GrafanaDashboard name prefix
*/}}
{{- define "k8s-observability-stack.dashboardPrefix" -}}
{{ include "k8s-observability-stack.fullname" . }}-dashboard
{{- end }}

{{/*
GrafanaDatasource name prefix
*/}}
{{- define "k8s-observability-stack.datasourcePrefix" -}}
{{ include "k8s-observability-stack.fullname" . }}-datasource
{{- end }}

{{/* ==========================================================================
   Image Helpers
   ========================================================================== */}}

{{/*
Return the proper image name for vmalert
*/}}
{{- define "k8s-observability-stack.vmalert.image" -}}
{{- $registryName := .Values.vmalert.image.registry | default "docker.io" -}}
{{- $repositoryName := .Values.vmalert.image.repository | default "victoriametrics/vmalert" -}}
{{- $tag := .Values.vmalert.image.tag | default "latest" -}}
{{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- end }}

{{/* ==========================================================================
   Namespace Helpers
   ========================================================================== */}}

{{/*
Allow the release namespace to be overridden
*/}}
{{- define "k8s-observability-stack.namespace" -}}
{{- if .Values.namespaceOverride }}
{{- .Values.namespaceOverride }}
{{- else }}
{{- .Release.Namespace }}
{{- end }}
{{- end }}

{{/* ==========================================================================
   Cluster Name Helper
   ========================================================================== */}}

{{/*
Get cluster name, defaulting to release name if not specified
*/}}
{{- define "k8s-observability-stack.clusterName" -}}
{{- if .Values.global.clusterName -}}
{{ .Values.global.clusterName }}
{{- else -}}
{{ .Release.Name }}
{{- end -}}
{{- end }}
