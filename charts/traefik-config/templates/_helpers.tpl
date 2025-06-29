{{- define "ju.ingress.middlewares" -}}
{{- $middlewares := list }}
{{- if and .Values.ingress.middleware.enabled .Values.ingress.middleware.ipAllowList }}
  {{- $middlewares = append $middlewares (printf "%s-%s@kubernetescrd" .Release.Namespace .Values.ingress.middleware.name) }}
{{- end }}
{{- if not .Values.ingress.accessControl.externalAccessAllowed }}
  {{- $middlewares = append $middlewares .Values.ingress.accessControl.internalAccessAllowListName }}
{{- end }}
{{- if $middlewares }}
traefik.ingress.kubernetes.io/router.middlewares: {{ join "," $middlewares | quote }}
{{- end }}
{{- end }}


{{- define "ju.ingress.externalHost" -}}
{{- coalesce .Values.ingress.accessControl.externalHost .Values.ingress.host .Values.global.ingress.host -}}
{{- end }}

{{- define "ju.ingress.internalHost" -}}
{{- coalesce .Values.ingress.accessControl.internalHost .Values.ingress.host .Values.global.ingress.host -}}
{{- end }}
