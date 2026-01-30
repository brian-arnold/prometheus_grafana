# Workflow for Dashboards and Alerts 

### Quick notes
- If you create a config map for dashboards/alerts that already exist and they have the same uids, the configmap will overwrite the existing ones
- If you've provisioned an alert, you can no longer use those evaluation groups when making new alerts

## Dashboards

### Workflow

Create the dashboard in Grafana, within a folder.

When the dashboard is mature, export the particular dashboard as JSON (can't export an entire folder), and put in a configmap, specifying that it's a dashboard and the folder in the config map:

```
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: monitoring
  name: test-storage
  labels:
    app: test-storage
    grafana_dashboard: "1"
  annotations:
    grafana_folder: "Test"
data: 
  dashboard1.json: |-
    YAML/JSON
```

if you ever need to make adjustments, you can copy the JSON content and import as a new dashboard. **You'll have to change the UID**. Make the edits you need, export the JSON to your clipboard, and replace the content in the configmap.

## Alerts

### Constraints

Alerts need to have an evaluation group that specifies how often the metric gets evaluated. If a provisioned alert uses an evaluation group, no new alerts made in the GUI can use this group (it's not available in drop down menu). Otherwise, they can have the same folder name

### Workflow

When designing new ALERT RULES (i.e. not recording rules) for the first time, specify an existing folder, evaluation group, and contact point

When done, we can export it to a ConfigMap

Under Alert rules tab on the left, go to Grafana-managed section

find the new alert rule, and on the right, you'll see an icon that looks like an "i" with a circle around it, "rule group details"

click this icon and you will see a button at the upper right to export JUST these rules

copy this code, and put it in an existing config map or a new one

```
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: monitoring
  name: test-storage-alerts
  labels:
    app: test-storage-alerts
    grafana_alert: "1"
  annotations:
    grafana_folder: "Test"
data: 
  alerts1.json: |-
    YAML/JSON
```

When you make new alert rules, you can no longer use the same evaluation group. Instead, give the new alert rule a suffix, e.g. `-dev`. Then, when this rule is ready to be moved to a config map for automatic provisioning, change the name field containing the evaluation group name to match the one you've decided to use in config-maps

- e.g. if you suffixed the eval group with `-dev`, just find and remove this string

- e.g. use `1hr-eval` for configmaps and `1hr-eval-dev` for experimenting

If you ever need to update the contact point, modify the receiver subfield in the configmap
