{{/*
Generate volumeMounts for enabled Longhorn volumes
Usage in parent/cronjob chart: {{ include "longhornstorage.volumeMounts" .Subcharts.longhornstorage | nindent 12 }}
*/}}
{{- define "longhornstorage.volumeMounts" -}}
{{- if .Values.enabled }}
{{- range $volumeName, $volume := .Values.volumes }}
{{- if and (or (not (hasKey $volume "enabled")) $volume.enabled) $volume.mount $volume.mount.path (or (not (hasKey $volume.mount "enabled")) $volume.mount.enabled) }}
- name: {{ printf "longhorn-%s" $volumeName }}
  mountPath: {{ $volume.mount.path }}
  {{- if $volume.mount.subPath }}
  subPath: {{ $volume.mount.subPath }}
  {{- end }}
  readOnly: {{ $volume.mount.readonly | default false }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Generate volume definitions for enabled Longhorn volumes
Usage in parent/cronjob chart: {{ include "longhornstorage.volumes" .Subcharts.longhornstorage | nindent 8 }}
*/}}
{{- define "longhornstorage.volumes" -}}
{{- if .Values.enabled }}
{{- range $volumeName, $volume := .Values.volumes }}
{{- if and (or (not (hasKey $volume "enabled")) $volume.enabled) }}
- name: {{ printf "longhorn-%s" $volumeName }}
  persistentVolumeClaim:
    claimName: {{ $volume.name | default (printf "%s-%s-pvc" $.Release.Name $volumeName) }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
