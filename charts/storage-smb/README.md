# storage-smb

This helm chart is intended to simplify mounting SMB shares in the cluster.

Requires the [csi-driver-smb](https://github.com/kubernetes-csi/csi-driver-smb).

Currently this helm chart only supports mounting shares into deployments,
not dynamically provisioning storage in a SMB share.

