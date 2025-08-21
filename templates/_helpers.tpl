{{- define "ju-backend.serviceAccountName" -}}
{{- if .Values.serviceAccount.name }}
  {{- .Values.serviceAccount.name }}
{{- else }}
  {{- include "ju-common.fullname" . }}-service-account
{{- end }}
{{- end }}

{{/*

*/}}
{{- define "ju-backend.isCustomizedServiceAccount" -}}
{{- if and .Values.serviceAccount.roleBindings (gt (len .Values.serviceAccount.roleBindings) 0) }}
true
{{- else }}
{{- /* Workaround: Leave this empty to evaluate to false, as "false" would be interpreted as a truthy string */ -}}
{{- end }}
{{- end }}

{{/*
Create default ingress host depending on global values
*/}}
{{- define "ju-common.ingressHost" -}}
{{- if (and .Values.ingress .Values.ingress.host) -}}
{{ .Values.ingress.host }}
{{- else if (and .Values.global.ingress .Values.global.ingress.host) -}}
{{ .Values.global.ingress.host }}
{{- else if (and (.Values.global.subDomain) (.Values.global.clusterUrl)) -}}
{{ .Values.global.subDomain }}.{{ .Values.global.clusterUrl }}
{{- else -}}
{{- fail "No valid ingress host is set. Please set ingress.host, global.ingress.host, or make sure that global.subDomain and global.clusterUrl are set properly via the deploy-pipeline in ArgoCD" }}
{{- end }}
{{- end }}

{{/*
Ingress path helper
*/}}
{{- define "ju-common.ingressPath" -}}
  {{- if not .Values.ingress.path -}}
    /
  {{- else -}}
    /{{ trimAll "/" .Values.ingress.path }}
  {{- end -}}
{{- end }}

{{/*
Source of truth for the service name
*/}}
{{- define "ju-common.serviceName" -}}
{{ include "ju-common.fullname" . }}
{{- end }}


{{/*
Expand the name of the chart.
*/}}
{{- define "ju-common.name" -}}
{{- default .Release.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "ju-common.fullname" -}}
{{- if .Values.fullnameOverride }}
  {{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else if ne .Values.global.simplifiedNames false }}
  {{- include "ju-common.name" . }}
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
{{- define "ju-common.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Concatenate all parts of an image specification into a fully qualified name.
*/}}
{{- define "ju-common.image" -}}
{{- if and (.Values.image.registry) (.Values.image.repository) -}}
  {{ .Values.image.registry }}/{{ .Values.image.repository }}:{{ required (print "The tag of the image \"" .Values.image.repository "\" has not been set.") .Values.image.tag | default .Chart.AppVersion }}
{{- else if .Values.image.name -}}
  {{ .Values.image.name }}:{{ required (print "The tag of the image \"" .Values.image.name "\" has not been set.") .Values.image.tag | default .Chart.AppVersion }}
{{- end -}}
{{- end -}}


{{/*
Common labels
*/}}
{{- define "ju-common.labels" -}}
helm.sh/chart: {{ include "ju-common.chart" . }}
{{ include "ju-common.podLabels" . }}
{{- if or .Chart.AppVersion .Values.image.tag }}
app.kubernetes.io/version: {{ if .Chart.AppVersion }}{{ .Chart.AppVersion | quote }}{{ else }}{{ .Values.image.tag | quote }}{{ end }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if .Values.global.Chart }}
  {{- if .Values.global.Chart.Name }}
app.kubernetes.io/part-of: {{ .Values.global.Chart.Name }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Common annotations
*/}}
{{- define "ju-common.annotations" -}}
logs.k8s.aeb.com/service: {{ .Chart.Name }}
logs.k8s.aeb.com/space: {{ .Release.Namespace }}
{{- if .Values.logFormat }}
logs.k8s.aeb.com/log-format:  {{ .Values.logFormat }}
{{- end }}
{{- if .Values.global.argoCd }}
gitops.k8s.aeb.com/branch: {{ .Values.global.argoCd.appSourceTargetRevision }}
gitops.k8s.aeb.com/path: {{ .Values.global.argoCd.appSourcePath }}
gitops.k8s.aeb.com/repository: {{ .Values.global.argoCd.appSourceRepoUrl }}
{{- end }}
{{- /* annotations to identitfy the corresponding ju-library-chart */ -}}
{{- if and .Values.libraryChart .Values.libraryChart.name }}
helm.k8s.aeb.com/component-chart-name: {{ .Values.libraryChart.name }}
helm.k8s.aeb.com/component-chart-version: {{ .Chart.Version }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "ju-common.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ju-common.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Pod labels
*/}}
{{- define "ju-common.podLabels" -}}
{{ include "ju-common.selectorLabels" . }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "ju-common.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "ju-common.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Check for production mode
*/}}
{{- define "ju-common.isProduction" -}}
{{- /* Check here whether productionOverride is empty or not set, but do not use the default check, as a value of false would lead to a wrong result */ -}}
{{- if or (eq (toString .Values.global.productionOverride) "") (include "ju-common.isNil" .Values.global.productionOverride) }}
{{- if .Values.global.production -}}
true
{{- else -}}
{{- /* Workaround: Leave this empty to evaluate to false, as "false" would be interpreted as a truthy string */ -}}
{{- end -}}
{{- else -}}
{{- if .Values.global.productionOverride -}}
true
{{- else -}}
{{- /* Workaround: Leave this empty to evaluate to false, as "false" would be interpreted as a truthy string */ -}}
{{- end -}}
{{- end -}}
{{- end }}


{{/*
Check if a value is undefined / nil
*/}}
{{- define "ju-common.isNil" -}}
{{- if kindIs "invalid" . -}}
true
{{- else -}}
{{- /* Workaround: Leave this empty to evaluate to false, as "false" would be interpreted as a truthy string */ -}}
{{- end -}}
{{- end }}


{{/*
Helper to evaluate a boolean value, that may be an actual boolean or a String.
Everything that is not exactly "true" is considered false.
*/}}
{{- define "ju-common.booleanValue" -}}
{{- if eq (toString .) "true" -}}
true
{{- else -}}
{{- /* Workaround: Leave this empty to evaluate to false, as "false" would be interpreted as a truthy string */ -}}
{{- end -}}
{{- end -}}


{{- define "ju-common.podSecurityContext" -}}
{{- if .Values.podSecurityContext -}}
{{ tpl (toYaml .Values.podSecurityContext) . }}
{{- else if .Values.usePodSecurityContextPreset -}}
{{ tpl (toYaml .Values.podSecurityContextPreset) . }}
{{- else -}}
{}
{{- end -}}
{{- end }}

{{- define "ju-common.containerSecurityContext" -}}
{{- if .Values.containerSecurityContext -}}
{{ tpl ( .Values.containerSecurityContext) . }}
{{- else if .Values.useContainerSecurityContextPreset -}}
{{ tpl (toYaml .Values.containerSecurityContextPreset) . }}
{{- else -}}
{}
{{- end -}}
{{- end }}
