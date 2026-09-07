{{- define "external-secrets.secret" }}
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: {{ .name }}
  {{- with .values.namespace }}
  namespace: {{ . }}
  {{- end }}
spec:
  target:
    name: {{ coalesce .values.targetName .name }}
    deletionPolicy: {{ .values.deletionPolicy }}
    template:
      type: {{ .values.secretType }}
      {{- if or .values.labels .values.annotations }}
      metadata:
        {{- with .values.labels }}
        labels:
          {{- toYaml . | nindent 10 }}
        {{- end }}
        {{- with .values.annotations }}
        annotations:
          {{- toYaml . | nindent 10 }}
        {{- end }}
      {{- end }}
      data:
{{- range $key, $val := .values.fields }}
{{- if or (kindIs "string" $val) ((hasKey $val "enabled") | ternary $val.enabled true) }}
        {{ $key }}: |-
          {{- if kindIs "string" $val }}
          {{ $val }}
          {{- else if $val.static }}
          {{ $val.static }}
          {{- else }}
          {{ printf "{{ index . %q }}" $key }}
          {{- end }}
{{- end }}
{{- end }}
  data:
{{- range $key, $val := .values.fields }}
{{- if or (kindIs "string" $val) ((hasKey $val "enabled") | ternary $val.enabled true) }}
  {{- if not (or (kindIs "string" $val) $val.static) }}
    - secretKey: {{ $key }}
      sourceRef:
        storeRef:
          name: {{ $val.storeRefName | default "bitwarden-login" }}
          kind: {{ $val.storeRefKind | default "ClusterSecretStore" }}
      remoteRef:
        key: {{ $val.remoteKey | default $.values.commonRemoteKey }}
        property: {{ $val.remoteProperty | default $key }}
  {{- end }}
{{- end }}
{{- end }}
{{- end }}
