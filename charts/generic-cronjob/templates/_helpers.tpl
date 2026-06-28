{{/*
Return the full name for the CronJob resource
*/}}
{{- define "generic-cronjob.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Return standard labels for the CronJob resource
*/}}
{{- define "generic-cronjob.labels" -}}
app.kubernetes.io/name: {{ include "generic-cronjob.name" . }}
app.kubernetes.io/component: cronjob
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Return the name for the CronJob resource
*/}}
{{- define "generic-cronjob.name" -}}
{{- if .Values.nameOverride }}
{{- .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Selector labels for the CronJob's NetworkPolicy, injected into the networkpolicy
subchart via networkpolicy.preset.selectorTemplate. This is invoked in the
networkpolicy chart's context, so it uses ONLY context-independent data
(a constant component label + the shared .Release.Name) — never .Chart.Name or
local .Values, which would resolve to the networkpolicy chart. The CronJob pod
template carries these same labels so the policy matches it in every usage mode
(standalone, subchart, composed). The release scope keeps it distinct from a
co-deployed generic-service Deployment.
*/}}
{{- define "generic-cronjob.netpolSelector" -}}
app.kubernetes.io/component: cronjob
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Distinct NetworkPolicy resource name for the CronJob, injected via
networkpolicy.preset.nameTemplate. Release-scoped (context-independent) and
suffixed so it never collides with a co-deployed generic-service policy.
*/}}
{{- define "generic-cronjob.netpolName" -}}
{{- printf "%s-cronjob-preset-cnp" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Return the image string for the main container
*/}}
{{- define "generic-cronjob.image" -}}
{{- if .Values.image.name }}
  {{- if .Values.image.registry }}{{ .Values.image.registry }}/{{ end }}{{- if .Values.image.repository }}{{ .Values.image.repository }}/{{ end }}{{ .Values.image.name }}{{- if .Values.image.tag }}:{{ .Values.image.tag }}{{ end }}
{{- end }}
{{- end }}
