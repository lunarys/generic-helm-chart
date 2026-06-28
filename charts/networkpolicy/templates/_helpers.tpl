{{/*
Derive the workload pod labels required by the preset's network-label
conventions (fromNetworkLabels/toNetworkLabels, external ingress, default
postgres). These labels go on the *workload pod* so peers whose policies key on
them will permit it — the policy rules alone are not enough.

Call with the networkpolicy values subtree as the context, e.g.:
  {{- include "networkpolicy.workloadLabels" .Values.networkpolicy }}
so it is independent of where the block is nested in the parent's values.
*/}}
{{- define "networkpolicy.workloadLabels" -}}
{{- if and .enabled .preset.enabled -}}
  {{- range $fromNetworkLabel := .preset.ingress.fromNetworkLabels -}}
    {{- nindent 0 "" }}{{ include "networkpolicy.workloadLabels.label" $fromNetworkLabel }}: {{ $.defaults.fromNetworkLabelValue }}
  {{- end }}
  {{- range $toNetworkLabel := .preset.egress.toNetworkLabels -}}
    {{- nindent 0 "" }}{{ include "networkpolicy.workloadLabels.label" $toNetworkLabel }}: {{ $.defaults.toNetworkLabelValue }}
  {{- end }}
  {{- if .preset.ingress.fromExternalIngressController -}}
    {{- nindent 0 "" }}{{ .defaults.customExternalIngressNetworkLabel }}: {{ .defaults.fromNetworkLabelValue }}
  {{- end }}
  {{- if .preset.egress.toDefaultPostgresDb -}}
    {{- nindent 0 "" }}{{ .defaults.defaultPostgresDbNetworkLabel }}: {{ .defaults.toNetworkLabelValue }}
  {{- end }}
{{- end }}
{{- end }}

{{- define "networkpolicy.workloadLabels.label" -}}
{{- if kindIs "string" . -}}
{{ . }}
{{- else -}}
{{ .label }}
{{- end -}}
{{- end }}
