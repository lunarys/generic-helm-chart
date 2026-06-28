# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository contains a collection of Helm charts for Kubernetes deployments. The core chart is `generic-service` (root of the repo), which wraps all helper subcharts. Helper charts live under `charts/` and can also be used standalone.

| Chart | Purpose |
|---|---|
| `generic-service` (root) | Main chart — wraps all helpers below |
| `charts/autoscale` | KEDA-based autoscaling |
| `charts/externalsecrets` | Bitwarden-backed ExternalSecrets |
| `charts/localstorage` | PVCs via local-path-provisioner |
| `charts/longhornstorage` | PVCs via Longhorn |
| `charts/networkpolicy` | Cilium network policies |
| `charts/smbstorage` | SMB/CIFS volume mounts |

## Commands

```bash
# Lint a chart
helm lint .
helm lint charts/smbstorage

# Dry-run template render
helm template test-release . --debug --dry-run
helm template test-release charts/smbstorage --debug --dry-run

# Install helm-unittest plugin (one-time)
helm plugin install https://github.com/helm-unittest/helm-unittest

# Run all unit tests for a chart
helm unittest . --with-subchart=false

# Run a single test file
helm unittest . --with-subchart=false -f tests/deployment_config_test.yaml
```

CI runs lint, template dry-run, and `helm unittest` for every chart in a matrix job (`.github/workflows/ci.yml`).

## Architecture

### generic-service dependency wiring

The root chart declares all helper charts as `dependencies` in `Chart.yaml`. Subchart values are passed through namespaced keys in `values.yaml` (e.g., `smbstorage:`, `longhornstorage:`, `externalsecrets:`, `networkpolicy:`, `autoscale:`).

`templates/deployment.yaml` integrates with subcharts using named template calls like `{{ include "smbstorage.volumeMounts" .Subcharts.smbstorage }}` — subcharts expose named templates for volume/volumeMount injection rather than rendering those pieces themselves.

### Template helpers

Shared label/name helpers follow the pattern `ju-common.*` (e.g., `ju-common.fullname`, `ju-common.labels`, `ju-common.image`). These are defined within the chart's own `_helpers.tpl` (not in a separate library chart). Chart-identity helpers are per-chart (e.g. `generic-cronjob.*` mirrors `ju-common.*` for the cronjob).

One cross-cutting convention helper is owned by the subchart instead: `networkpolicy.workloadLabels` lives in `charts/networkpolicy/templates/_helpers.tpl` and is called from each consumer's **pod template** with the networkpolicy values subtree as context — `include "networkpolicy.workloadLabels" .Values.networkpolicy`. It derives the `custom.network/*` pod labels (from `fromNetworkLabels` / `toNetworkLabels` / `fromExternalIngressController` / `toDefaultPostgresDb`) that peers' policies key on. Passing the subtree (not `.`) keeps it independent of where the block is nested.

### externalsecrets

The `externalsecrets` chart generates `ExternalSecret` resources backed by Bitwarden via ClusterSecretStore. It supports:
- A default secret (all fields under `fields:`) with `commonRemoteKey` as default remote key
- Multiple named secrets under `secrets:` (each inherits top-level settings and can override)

Store names: `bitwarden-login` (username/password), `bitwarden-fields` (custom fields), `bitwarden-notes`, `bitwarden-attachments`.

### smbstorage

Handles SMB mounts with optional Kubernetes Secret or ExternalSecret for credentials. Each volume is a map entry under `volumes:`. The chart renders PV + PVC (static binding) + optional credential secret.

### Config mounting

The `config` key in `values.yaml` supports three mount modes:
- `config.mount.env: true` — inject all keys as env vars via `envFrom`
- `config.mount.path: /some/dir` — mount the ConfigMap as a directory (any number of keys)
- `config.mount.subPath: /exact/file.yaml` — mount a single key as a file at an exact path. **Requires exactly one key** in `config.values`; the template `fail`s on multiple keys (use `path` mode for several files). Note: `keys` returns unordered map order in Helm — always `sortAlpha` before positional access (`first`/`index`).

### networkpolicy preset selector & name

The preset CiliumNetworkPolicy's endpoint selector and resource name are **injectable** so a consumer can scope them to its own workload:
- `preset.useChartEndpointSelector: true` selects via `preset.selectorTemplate` (default `ju-common.selectorLabels`, release-based — used by generic-service).
- `preset.nameTemplate` derives the resource name (default `<release>-preset-cnp`).

Both templates render **in the networkpolicy chart's context**, so a consumer's provider may use only context-independent data — `.Release.*`, `.Values.global.*`, constants — never `.Chart.Name` or local `.Values` (those resolve to the networkpolicy chart). generic-cronjob uses this to give its policy a distinct component-based selector (`generic-cronjob.netpolSelector`) and a non-colliding name (`generic-cronjob.netpolName`). Limitation: the selector/name can't be made unique per-instance across multiple consumers in one release — override `preset.endpointSelector` + `preset.name` explicitly for that.

### Security context presets

By default, pods run with `runAsNonRoot: true`, UID 1000, GID 3000, fsGroup 2000, and `seccompProfile: RuntimeDefault`. Containers drop all capabilities with `allowPrivilegeEscalation: false`. These presets can be replaced by setting `podSecurityContext` / `containerSecurityContext` directly.

### Ingress

Two ingresses can coexist: an internal one (with Traefik allowlist middleware) and an external one (`ingress.external.enabled: true`). TLS ClusterIssuer falls back: `ingress.tls.clusterIssuer` → `global.baseSettings.tls.internalClusterIssuer` → `global.baseSettings.tls.clusterIssuer`.

## Test structure

Tests live in `tests/` (for `generic-service`) and `charts/<name>/tests/` (for subcharts). Each file is a `helm-unittest` suite targeting specific template files. Tests use `set:` to provide values and `asserts:` with JSONPath matchers.
