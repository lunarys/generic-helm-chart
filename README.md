# Helm Charts

A collection of Helm charts for deploying generic services on Kubernetes,
mainly focused on applications consisting of a single Docker image.

The core chart is `generic-service`, which provides a single, reusable interface for deploying containerised applications — handling deployments, ingress, storage, secrets, network policies, and autoscaling through a set of composable helper charts. The helper charts can also be used standalone.

Large parts of this can be viewed in action in my [public gitops repository](https://github.com/lunarys/gitops),
in the [apps directory](https://github.com/lunarys/gitops/tree/main/03_apps/apps).

> **Note:** These charts may contain defaults specific to my setup and are not fully generic (yet).

## Charts

| Chart | Description |
|---|---|
| `generic-service` | Generic chart for service deployments — wraps all helper charts below |
| `autoscale` | Autoscaling helper using KEDA |
| `externalsecrets` | External secrets helper (Bitwarden) |
| `localstorage` | Persistent storage via local-path-provisioner |
| `longhornstorage` | In-cluster storage via Longhorn |
| `networkpolicy` | Network policy helper (Cilium) |
| `smbstorage` | SMB storage helper |

## Usage

```bash
helm install <release> oci://ghcr.io/lunarys/charts/generic-service --version <version> -f <values-file>
```

All charts are versioned together. See [Releases](https://github.com/lunarys/generic-helm-chart/releases) for available versions.
