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
LB-IPAM service helpers — intent-based LoadBalancer IP exposure.
An app author sets only loadBalancerIPs (or the deprecated externalIPs alias); these
helpers derive the Cilium LB-IPAM plumbing. Each helper takes a dict:
  "svc" <per-service config map> "ctx" <root context $>
and the calling template combines their output:
  - ju-common.service.resolvedType   → final spec.type string
  - ju-common.service.annotations    → metadata.annotations (auto lbipam + user, user wins)
  - ju-common.service.extraLabels    → extra metadata.labels (auto pool label + user, user wins)
  - ju-common.service.ipFamily       → spec.ipFamilyPolicy / spec.ipFamilies block
  - ju-common.service.isIPv6         → internal: classify a single IP string

Usage in templates:
  {{- $svcCtx := dict "svc" $svc "ctx" $ }}
  {{- $resolvedType := include "ju-common.service.resolvedType" $svcCtx }}
  ... (see templates/service.yaml and templates/services.yaml)
*/}}

{{/*
  Helper: returns "true" if the IP string is IPv6 (contains colon).
*/}}
{{- define "ju-common.service.isIPv6" -}}
{{- if contains ":" . -}}true{{- end -}}
{{- end -}}

{{/*
  Helper: emit the FINAL resolved service type string.
  Precedence: explicit user-set type > LoadBalancer (when IPs present) > ClusterIP.
  Always emits a concrete value, so callers can use it verbatim.
*/}}
{{- define "ju-common.service.resolvedType" -}}
{{- $svc := .svc -}}
{{- $lbIPs := $svc.loadBalancerIPs | default list -}}
{{- $extIPs := $svc.externalIPs | default list -}}
{{- $ips := ternary $lbIPs $extIPs (not (empty $lbIPs)) -}}
{{- if $svc.type -}}
  {{- $svc.type -}}
{{- else if $ips -}}
  {{- "LoadBalancer" -}}
{{- else -}}
  {{- "ClusterIP" -}}
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
{{- /* Merge user over auto: dest=user (deep-copied so Values is untouched), src=auto fills gaps; user wins on conflict */ -}}
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
  The two fields are INDEPENDENT power-user overrides; each is decided on its own:
    - ipFamilyPolicy = user value if set, else RequireDualStack when both an IPv4
      and an IPv6 are present, else nothing.
    - ipFamilies = user value (verbatim) if set, else [IPv4, IPv6] when both
      families present, else nothing.
  A user can set one field without the other.
*/}}
{{- define "ju-common.service.ipFamily" -}}
{{- $svc := .svc -}}
{{- $lbIPs := $svc.loadBalancerIPs | default list -}}
{{- $extIPs := $svc.externalIPs | default list -}}
{{- $ips := ternary $lbIPs $extIPs (not (empty $lbIPs)) -}}
{{- $userPolicy := $svc.ipFamilyPolicy | default "" -}}
{{- $userFamilies := $svc.ipFamilies | default list -}}
{{- /* Detect whether both IP families are present (drives the auto defaults). */ -}}
{{- $hasV4 := false -}}
{{- $hasV6 := false -}}
{{- range $ip := $ips -}}
  {{- if include "ju-common.service.isIPv6" $ip -}}
    {{- $hasV6 = true -}}
  {{- else -}}
    {{- $hasV4 = true -}}
  {{- end -}}
{{- end -}}
{{- $dualStack := and $hasV4 $hasV6 -}}
{{- /* ipFamilyPolicy: user wins, else auto RequireDualStack when dual-stack. */ -}}
{{- if $userPolicy -}}
ipFamilyPolicy: {{ $userPolicy }}
{{- else if $dualStack -}}
ipFamilyPolicy: RequireDualStack
{{- end -}}
{{- /* ipFamilies: user wins (verbatim), else auto [IPv4, IPv6] when dual-stack. */ -}}
{{- if $userFamilies }}
ipFamilies:
  {{- range $userFamilies }}
  - {{ . }}
  {{- end }}
{{- else if $dualStack }}
ipFamilies:
  - IPv4
  - IPv6
{{- end -}}
{{- end -}}

{{/*
  Helper: emit allocateLoadBalancerNodePorts line (or nothing).

  Motivation: Kubernetes defaults allocateLoadBalancerNodePorts to true for LoadBalancer
  services, which causes Kubernetes to allocate a NodePort for every service port. In a
  Cilium kube-proxy-replacement + LB-IPAM cluster, traffic is routed directly to the
  LoadBalancer IP via eBPF/DSR, so those NodePorts are unused. They only waste the
  nodeport range and open an extra port on every node.

  Resolution:
    - If the resolved service type is NOT LoadBalancer → emit nothing (field must be absent;
      it is only meaningful for LoadBalancer services).
    - If type IS LoadBalancer → emit `true` only when the service explicitly set
      allocateLoadBalancerNodePorts: true; otherwise emit `false` (the chart's opinionated
      default — both "unset" and an explicit false resolve to false, which is safe for
      Cilium LB-IPAM clusters).

  Call with the same dict used by other service helpers:
    "svc" <per-service config map> "ctx" <root context $>
    "resolvedType" <string from ju-common.service.resolvedType>
*/}}
{{- define "ju-common.service.allocateNodePorts" -}}
{{- $svc := .svc -}}
{{- $resolvedType := .resolvedType -}}
{{- if eq $resolvedType "LoadBalancer" -}}
{{- if eq (toString (get $svc "allocateLoadBalancerNodePorts")) "true" -}}
allocateLoadBalancerNodePorts: true
{{- else -}}
allocateLoadBalancerNodePorts: false
{{- end -}}
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
{{ include "networkpolicy.workloadLabels" .Values.networkpolicy }}
{{ include "ju-common.selectorLabels" . }}
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
