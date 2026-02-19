# Troubleshooting and Advanced Topics

## Changing admin password
I've had better luck managing the admin password through this command compared to editing within the GUI, where I noticed it stoppped working (but this could have been due to upgrades), and if I get locked out I can just do the following:
```
kubectl exec -n monitoring deployment/prometheus-grafana -- grafana-cli admin reset-admin-password <PASSWORD> 
```

## Putting grafana dashboards in subfolders via configmaps
- For making grafana dashboards via config maps AND in subfolders, see [here](https://github.com/grafana/helm-charts/issues/526)
  - See any configmap in `manifests/dashboard_config_maps/` for a working example — each one uses the `grafana_folder` annotation to place the dashboard in a named subfolder
- See [here](https://github.com/prometheus-community/helm-charts/issues/4493) for how to put default dashboards into a subfolder

## Deleting grafana dashboards that automatically come with helm installation
- these cannot be removed in the GUI
- You need to delete the [ConfigMaps](https://stackoverflow.com/questions/65308780/disable-default-dashboards-in-the-prometheus-community-helm-chart#:~:text=I%20was%20facing%20the%20same%20issue%20and%20the%20way%20I%20resolved%20it%20was%20to%20remove%20the%20respective%20config%20maps%20which%20have%20been%20generated%20by%20the%20kube%2Dprometheus%2Dstack%20helm%20chart.), you should see config maps with names corresponding to the provisioned dashboards.
