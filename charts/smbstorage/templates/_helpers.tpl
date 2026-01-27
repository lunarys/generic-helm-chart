{{/*
Generate volume name with release prefix
*/}}
{{- define "smbstorage.volumeName" -}}
{{- $volumeName := .volumeName -}}
{{- $release := .Release.Name -}}
{{- printf "%s-%s" $release $volumeName -}}
{{- end -}}

{{/*
Generate PV name for a volume
*/}}
{{- define "smbstorage.pvName" -}}
{{- $volume := .volume -}}
{{- $volumeName := include "smbstorage.volumeName" . -}}
{{- if and $volume.pv $volume.pv.name -}}
{{- $volume.pv.name -}}
{{- else -}}
{{- printf "%s-pv-smb" $volumeName -}}
{{- end -}}
{{- end -}}

{{/*
Generate PVC name for a volume
*/}}
{{- define "smbstorage.pvcName" -}}
{{- $volume := .volume -}}
{{- $volumeName := include "smbstorage.volumeName" . -}}
{{- if and $volume.pvc $volume.pvc.name -}}
{{- $volume.pvc.name -}}
{{- else -}}
{{- printf "%s-pvc-smb" $volumeName -}}
{{- end -}}
{{- end -}}

{{/*
Generate Secret name for a volume
*/}}
{{- define "smbstorage.secretName" -}}
{{- $volume := .volume -}}
{{- $volumeName := include "smbstorage.volumeName" . -}}
{{- if and $volume.secret $volume.secret.name -}}
{{- $volume.secret.name -}}
{{- else if and $volume.externalsecret $volume.externalsecret.name -}}
{{- $volume.externalsecret.name -}}
{{- else -}}
{{- printf "%s-smb-creds" $volumeName -}}
{{- end -}}
{{- end -}}

{{/*
Generate SMB source URI for a volume
*/}}
{{- define "smbstorage.smbSource" -}}
{{- $volume := .volume -}}
{{- if $volume.smb.source -}}
{{- $volume.smb.source -}}
{{- else -}}
{{- printf "//%s/%s" $volume.smb.host $volume.smb.share -}}
{{- end -}}
{{- end -}}

{{/*
Generate volumeMounts for enabled SMB volumes
Usage in parent/cronjob chart: {{ include "smbstorage.volumeMounts" .Subcharts.smbstorage | nindent 12 }}
*/}}
{{- define "smbstorage.volumeMounts" -}}
{{- if .Values.enabled }}
{{- range $volumeName, $volume := .Values.volumes }}
{{- if and (or (not (hasKey $volume "enabled")) $volume.enabled) $volume.mount $volume.mount.path (or (not (hasKey $volume.mount "enabled")) $volume.mount.enabled) }}
- name: {{ printf "smb-%s" $volumeName }}
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
Generate volume definitions for enabled SMB volumes
Usage in parent/cronjob chart: {{ include "smbstorage.volumes" .Subcharts.smbstorage | nindent 8 }}
*/}}
{{- define "smbstorage.volumes" -}}
{{- if .Values.enabled }}
{{- range $volumeName, $volume := .Values.volumes }}
{{- if and (or (not (hasKey $volume "enabled")) $volume.enabled) }}
- name: {{ printf "smb-%s" $volumeName }}
  persistentVolumeClaim:
    claimName: {{ include "smbstorage.pvcName" (dict "volume" $volume "volumeName" $volumeName "Release" $.Release) }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}