{{/*
Compute the final Traefik middleware annotation value.
Call with a dict: "defaultMiddlewares" <string|list> "traefikConfig" <map>
  "tlsEnabled" <bool> "httpsRedirectMiddleware" <string>
Order: defaultMiddlewares, httpsRedirectMiddleware (when TLS+httpsRedirect), chart middlewares
Both defaultMiddlewares and traefikConfig.middlewares accept a comma-separated string or a list.
*/}}
{{- define "ju-common.traefik.computeMiddlewares" -}}
{{- $traefikConfig := .traefikConfig | default dict }}
{{- $middlewareParts := list }}
{{- if not $traefikConfig.disableDefaultMiddlewares }}
  {{- if kindIs "slice" .defaultMiddlewares }}
    {{- $middlewareParts = concat $middlewareParts .defaultMiddlewares }}
  {{- else if .defaultMiddlewares }}
    {{- $middlewareParts = append $middlewareParts .defaultMiddlewares }}
  {{- end }}
{{- end }}
{{- if and .tlsEnabled $traefikConfig.httpsRedirect .httpsRedirectMiddleware }}
  {{- $middlewareParts = append $middlewareParts .httpsRedirectMiddleware }}
{{- end }}
{{- if kindIs "slice" $traefikConfig.middlewares }}
  {{- $middlewareParts = concat $middlewareParts $traefikConfig.middlewares }}
{{- else if $traefikConfig.middlewares }}
  {{- $middlewareParts = append $middlewareParts $traefikConfig.middlewares }}
{{- end }}
{{- join "," $middlewareParts }}
{{- end }}


{{/*
Compute LB IPAM service fields for a single service config dict.
Call with a dict: "svc" <per-service config map> "ctx" <root context $>
Emits a YAML fragment (indented 0) containing:
  - resolved type (if IPs present → LoadBalancer, else passthrough)
  - metadata.annotations block (auto lbipam + user annotations, user wins)
  - metadata.labels block (auto pool label + user labels, user wins)
  - ipFamilyPolicy / ipFamilies (auto dual-stack or user override)

Usage in templates:
  {{- include "ju-common.service.lbipam" (dict "svc" $svc "ctx" $) | nindent 0 }}
*/}}

{{/*
  Helper: returns "true" if the IP string is IPv6 (contains colon).
*/}}
{{- define "ju-common.service.isIPv6" -}}
{{- if contains ":" . -}}true{{- end -}}
{{- end -}}

{{/*
  Helper: emit the resolved service type.
  If IPs present and user didn't set type → LoadBalancer.
  If no IPs → empty string (caller keeps its own default).
  Emits just the value string (no key).
*/}}
{{- define "ju-common.service.resolvedType" -}}
{{- $svc := .svc -}}
{{- $lbIPs := $svc.loadBalancerIPs | default list -}}
{{- $extIPs := $svc.externalIPs | default list -}}
{{- $ips := ternary $lbIPs $extIPs (not (empty $lbIPs)) -}}
{{- if $ips -}}
  {{- $svc.type | default "LoadBalancer" -}}
{{- else -}}
  {{- $svc.type | default "" -}}
{{- end -}}
{{- end -}}

{{/*
  Helper: emit the annotations map (merged: auto + user; user wins).
  Emits a YAML map fragment or empty string.
*/}}
{{- define "ju-common.service.annotations" -}}
{{- $svc := .svc -}}
{{- $lbIPs := $svc.loadBalancerIPs | default list -}}
{{- $extIPs := $svc.externalIPs | default list -}}
{{- $ips := ternary $lbIPs $extIPs (not (empty $lbIPs)) -}}
{{- $auto := dict -}}
{{- if $ips -}}
  {{- $_ := set $auto "lbipam.cilium.io/ips" (join "," $ips) -}}
{{- end -}}
{{- $userAnnotations := $svc.annotations | default dict -}}
{{- /* Merge: start with auto, then overlay user (user wins on conflict) */ -}}
{{- $merged := merge (deepCopy $userAnnotations) $auto -}}
{{- if $merged -}}
{{ toYaml $merged }}
{{- end -}}
{{- end -}}

{{/*
  Helper: emit extra labels map (merged: auto pool label + user labels; user wins).
  Pool label key/value are read from global.baseSettings.loadBalancerPool (with sane defaults),
  so they can be overridden cluster-wide via ArgoCD app values.
  Emits a YAML map fragment or empty string.
*/}}
{{- define "ju-common.service.extraLabels" -}}
{{- $svc := .svc -}}
{{- $ctx := .ctx -}}
{{- $lbIPs := $svc.loadBalancerIPs | default list -}}
{{- $extIPs := $svc.externalIPs | default list -}}
{{- $ips := ternary $lbIPs $extIPs (not (empty $lbIPs)) -}}
{{- $auto := dict -}}
{{- if $ips -}}
  {{- $bs := ($ctx.Values.global.baseSettings | default dict) -}}
  {{- $lbPoolCfg := (get $bs "loadBalancerPool" | default dict) -}}
  {{- $poolKey := (get $lbPoolCfg "labelKey" | default "custom.network/lb-pool") -}}
  {{- $poolVal := (get $lbPoolCfg "labelValue" | default "static") -}}
  {{- $_ := set $auto $poolKey $poolVal -}}
{{- end -}}
{{- $userLabels := $svc.labels | default dict -}}
{{- $merged := merge (deepCopy $userLabels) $auto -}}
{{- if $merged -}}
{{ toYaml $merged }}
{{- end -}}
{{- end -}}

{{/*
  Helper: emit ipFamilyPolicy and ipFamilies lines (or nothing).
  Auto-detection: both IPv4 and IPv6 in IPs AND user didn't set ipFamilyPolicy
    → RequireDualStack + [IPv4, IPv6].
  User-set ipFamilyPolicy always wins (rendered verbatim).
  User-set ipFamilies always wins (rendered verbatim).
*/}}
{{- define "ju-common.service.ipFamily" -}}
{{- $svc := .svc -}}
{{- $lbIPs := $svc.loadBalancerIPs | default list -}}
{{- $extIPs := $svc.externalIPs | default list -}}
{{- $ips := ternary $lbIPs $extIPs (not (empty $lbIPs)) -}}
{{- $userPolicy := $svc.ipFamilyPolicy | default "" -}}
{{- $userFamilies := $svc.ipFamilies | default list -}}
{{- if $userPolicy -}}
ipFamilyPolicy: {{ $userPolicy }}
  {{- if $userFamilies }}
ipFamilies:
    {{- range $userFamilies }}
  - {{ . }}
    {{- end }}
  {{- end }}
{{- else if $ips -}}
  {{- /* auto dual-stack detection */ -}}
  {{- $hasV4 := false -}}
  {{- $hasV6 := false -}}
  {{- range $ip := $ips -}}
    {{- if include "ju-common.service.isIPv6" $ip -}}
      {{- $hasV6 = true -}}
    {{- else -}}
      {{- $hasV4 = true -}}
    {{- end -}}
  {{- end -}}
  {{- if and $hasV4 $hasV6 -}}
ipFamilyPolicy: RequireDualStack
ipFamilies:
  - IPv4
  - IPv6
  {{- end -}}
{{- else if $userFamilies -}}
ipFamilies:
  {{- range $userFamilies }}
  - {{ . }}
  {{- end }}
{{- end -}}
{{- end -}}


{{/*
Resolve cert-manager ClusterIssuer for the internal ingress.
Resolution order: ingress.tls.clusterIssuer
  → global.baseSettings.tls.internalClusterIssuer → global.baseSettings.tls.clusterIssuer
*/}}
{{- define "ju-common.tls.internalClusterIssuer" -}}
{{- $bs := (.Values.global.baseSettings | default dict) }}
{{- $bsTls := (get $bs "tls" | default dict) }}
{{- coalesce .Values.ingress.tls.clusterIssuer (get $bsTls "internalClusterIssuer") (get $bsTls "clusterIssuer") }}
{{- end }}

{{/*
Resolve cert-manager ClusterIssuer for the external ingress.
Resolution order: ingress.external.tls.clusterIssuer
  → global.baseSettings.tls.externalClusterIssuer → global.baseSettings.tls.clusterIssuer
*/}}
{{- define "ju-common.tls.externalClusterIssuer" -}}
{{- $bs := (.Values.global.baseSettings | default dict) }}
{{- $bsTls := (get $bs "tls" | default dict) }}
{{- $extTls := (.Values.ingress.external.tls | default dict) }}
{{- coalesce (get $extTls "clusterIssuer") (get $bsTls "externalClusterIssuer") (get $bsTls "clusterIssuer") }}
{{- end }}

{{/*
Ingress external host
*/}}
{{- define "ju-common.ingress.externalHost" -}}
{{- .Values.ingress.external.host -}}
{{- end }}

{{/*
Ingress internal host
*/}}
{{- define "ju-common.ingress.internalHost" -}}
{{- coalesce .Values.ingress.host .Values.global.ingress.host -}}
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

{{- define "ju-common.ingressName" -}}
{{ .Values.ingress.name | default (include "ju-common.fullname" .) }}
{{- end -}}

{{/*
Source of truth for the service name
*/}}
{{- define "ju-common.serviceName" -}}
{{ .Values.service.name | default (include "ju-common.fullname" .) }}
{{- end }}


{{/*
Expand the name of the chart.
*/}}
{{- define "ju-common.name" -}}
{{- coalesce .Values.nameOverride .Values.global.nameOverride .Release.Name | trunc 63 | trimSuffix "-" }}
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
  {{- $name := include "ju-common.name" . }}
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
{{- /* Nothing here right now */ -}}
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
{{ include "ju-common.networkpolicyLabels" . }}
{{ include "ju-common.selectorLabels" . }}
{{- end }}

{{/*
Networkpolicy labels - Used for simplified networkpolicy handling
*/}}
{{- define "ju-common.networkpolicyLabels" -}}
{{- if and .Values.networkpolicy.enabled .Values.networkpolicy.preset.enabled -}}
  {{- range $fromNetworkLabel := .Values.networkpolicy.preset.ingress.fromNetworkLabels -}}
    {{- nindent 0 "" }}{{ include "ju-common.networkpolicyLabels.label" $fromNetworkLabel }}: {{ $.Values.networkpolicy.defaults.fromNetworkLabelValue }}
  {{- end }}
  {{- range $toNetworkLabel := .Values.networkpolicy.preset.egress.toNetworkLabels -}}
    {{- nindent 0 "" }}{{ include "ju-common.networkpolicyLabels.label" $toNetworkLabel }}: {{ $.Values.networkpolicy.defaults.toNetworkLabelValue }}
  {{- end }}
  {{- if .Values.networkpolicy.preset.ingress.fromExternalIngressController -}}
    {{- nindent 0 "" }}{{ .Values.networkpolicy.defaults.customExternalIngressNetworkLabel }}: {{ .Values.networkpolicy.defaults.fromNetworkLabelValue }}
  {{- end }}
  {{- if .Values.networkpolicy.preset.egress.toDefaultPostgresDb -}}
    {{- nindent 0 "" }}{{ .Values.networkpolicy.defaults.defaultPostgresDbNetworkLabel }}: {{ .Values.networkpolicy.defaults.toNetworkLabelValue }}
  {{- end }}
{{- end }}
{{- end }}

{{- define "ju-common.networkpolicyLabels.label" -}}
{{- if kindIs "string" . -}}
{{ . }}
{{- else -}}
{{ .label }}
{{- end -}}
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
{{ tpl (toYaml .Values.containerSecurityContext) . }}
{{- else if .Values.useContainerSecurityContextPreset -}}
{{ tpl (toYaml .Values.containerSecurityContextPreset) . }}
{{- else -}}
{}
{{- end -}}
{{- end }}

{{/*
Resolve the name of the secret created by the postgresdb-user-operator for this release.
*/}}
{{- define "postgresdb.secretName" -}}
{{- .Values.postgresdb.secretName | default (printf "%s-pgcreds" (.Values.postgresdb.nameOverride | default (include "ju-common.fullname" .))) }}
{{- end }}
