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
{{- $np := . -}}
{{- if and $np.enabled $np.preset.enabled -}}
  {{- range $label := $np.preset.ingress.fromNetworkLabels -}}
    {{- nindent 0 "" }}{{ include "networkpolicy.workloadLabels.label" $label }}: {{ $np.defaults.fromNetworkLabelValue }}
  {{- end }}
  {{- range $label := $np.preset.egress.toNetworkLabels -}}
    {{- nindent 0 "" }}{{ include "networkpolicy.workloadLabels.label" $label }}: {{ $np.defaults.toNetworkLabelValue }}
  {{- end }}
  {{- if $np.preset.ingress.fromExternalIngressController -}}
    {{- nindent 0 "" }}{{ $np.defaults.customExternalIngressNetworkLabel }}: {{ $np.defaults.fromNetworkLabelValue }}
  {{- end }}
  {{- if $np.preset.egress.toDefaultPostgresDb -}}
    {{- nindent 0 "" }}{{ $np.defaults.defaultPostgresDbNetworkLabel }}: {{ $np.defaults.toNetworkLabelValue }}
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

{{/*
Render the local-subnet CIDR list as YAML list items. `defaults.localSubnetCidr`
may be a single string (legacy) or a list of strings — on a dual-stack LAN it
carries both the IPv4 range and the IPv6 ULA prefix so `fromLocalSubnet` /
`toLocalSubnet` admit clients of either family. Call with the whole chart
context; the caller supplies indentation.
*/}}
{{- define "networkpolicy.localSubnetCidrs" -}}
{{- $cidrs := .Values.defaults.localSubnetCidr -}}
{{- if kindIs "string" $cidrs -}}
- {{ $cidrs }}
{{- else -}}
{{ toYaml $cidrs }}
{{- end -}}
{{- end }}
