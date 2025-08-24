# Working with Longhorn Volumes

This guide explains how to use Longhorn volumes with this Helm chart.

## 1. Configure a PersistentVolumeClaim (PVC)

Define a PVC using this helm chart.

## 2. Dynamic Provisioning

When you deploy the chart, the Longhorn CSI driver dynamically creates a PersistentVolume (PV) for your PVC.

## 3. Create a Backup of the PV

1. Go to the Longhorn UI.
2. Select the volume (PV) you want to back up.
3. Create a backup of the pv.

## 4. Disable dynamic provisioning

Copy the name of the dynamically created pv to the pvName setting.
This ensures the pvc will only bing to this pv.

# Restoring

## 5. Restore the pv using longhorn

Use longhorn to restore the required pv.

### 5.1. Make pv bindable

(Not sure if required.) 
After restoring the pv its status might be `Released`,
change that by removing the claimRef:

```bash
kubectl patch pv pvc-b20308e2-d3f4-4fb8-800d-ab4fae98a405 -p '{"spec":{"claimRef": null}}'
```

## 6. Everything is Back

Your application will now use the restored data from the backup via the PVC.


# Untested, alternative way

(Suggested by copilot, might be a hallucination.)

Use the annotation

```
longhorn.io/backup-restore: <backup-url>
```

on the pvc. The URL can be retrieved from Longhorn UI and looks like this:

```
cifs://erolas.elda/test-longhorn?backup=backup-b30e7c19ec6a4de0&volume=pvc-b20308e2-d3f4-4fb8-800d-ab4fae98a405
```

It looks like the backup name and volume name can be retrieved from the longhorn backup location, from the `.cfg` files.

https://longhorn.io/docs/1.9.0/advanced-resources/data-recovery/recover-without-system/
