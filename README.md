# Helm Charts

Set up access to gitlab OCI registry:

Create access token: Role: Developer, Scope: read_registry

```
helm registry login registry.gitlab.com
```

Repo: e.g. `oci://registry.gitlab.com/juulun/helm-charts/charts`,
Chart: `generic-service`

