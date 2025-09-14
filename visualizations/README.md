JSON files in the json subdir were exported from grafana. These could be imported to another grafana instance via copy-pasting.

However, you can also put these JSON strings in a config map and load them into grafana with e.g. `kubectl aply -f temperature.yaml`.

This way, dashboards could be managed as kubernetes resources and backed up by e.g. Velero.