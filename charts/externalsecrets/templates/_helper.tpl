{{- define "external-secrets.hasEnabledFields" -}}
{{- range $key, $val := .Values.fields }}
{{- if or (kindIs "string" $val) ((hasKey $val "enabled") | ternary $val.enabled true) }}
true
{{- end }}
{{- end }}
{{- end }}
