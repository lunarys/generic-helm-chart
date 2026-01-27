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
Return the image string for the main container
*/}}
{{- define "generic-cronjob.image" -}}
{{- if .Values.image.name }}
  {{- if .Values.image.registry }}{{ .Values.image.registry }}/{{ end }}{{- if .Values.image.repository }}{{ .Values.image.repository }}/{{ end }}{{ .Values.image.name }}{{- if .Values.image.tag }}:{{ .Values.image.tag }}{{ end }}
{{- end }}
{{- end }}
