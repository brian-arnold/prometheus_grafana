# Background
This prometheus/grafana stack deployment is simple. Prometheus seems to require local storage, so here we deploy a single instance of prometheus and grafana on a specific node (at-compute010) and use subdirectories within /mnt/md0 for these apps to store their data. If these pods ever crash, we have them deploy to the same node so that they still have access to their data within node-specific /mnt/md0. 

See [here](https://docs.ray.io/en/latest/cluster/kubernetes/k8s-ecosystem/prometheus-grafana.html#using-prometheus-and-grafana) for how to monitor Ray resources with prometheus and grafana.

See [here](https://github.com/minio/directpv/blob/master/docs/monitoring.md) for how to scrape directpv metrics with prometheus.

# Installation
- add prometheus helm repo and update
    - `helm repo add prometheus-community https://prometheus-community.github.io/helm-charts`
    - `helm repo update`
- create monitoring namespace
    - `kubectl create namespace monitoring`
- statically provision local storage (PV and storage classes) by applying this file
    - `kubectl apply -f persistentVolume_StorageClass.yaml`
    - if using local storage on /mnt/md0 of a local compute node, you need to also do `sudo chown -R 1000:2000 /mnt/md0/k8s_apps/prometheus` since prometheus runs with user id 1000 and group id 2000
- confirm resouces created
    - `kubectl get pv`
    - `kubectl get sc`
- helm install kube-prom-stack, using `values.yaml` file to have helm create PersistentVolumeClaims for the PVs based on the storage classes
    - `helm install prometheus prometheus-community/kube-prometheus-stack -f values.yaml --namespace monitoring`
    - this `values.yaml` file also creates an additional servicemonitor for `nvidia-dcgm-exporter` for GPU monitoring

# Change admin password
I've had better luck managing the admin password through this command compared to editing within the GUI, where I noticed it stoppped working (but this could have been due to upgrades), and if I get locked out I can just do the following:
```
kubectl exec -n monitoring deployment/prometheus-grafana -- grafana-cli admin reset-admin-password <PASSWORD> 
```

# Extra configuration
- The kube-prometheus-stack provides infrastructure monitoring for all pods via kubelet, but Ray application metrics require some custom configuration.
- As suggested by the Ray [docs](https://docs.ray.io/en/latest/cluster/kubernetes/k8s-ecosystem/prometheus-grafana.html#using-prometheus-and-grafana) for setting up prometheus/grafana with k8s, apply the following pod monitors 
  - `kubectl apply -f ray_podmonitors.yaml`
- See docs in `ray_podmonitors.yaml` for more info.

# Managing Alert rules as files

### Exporting/importing alert rules

Although dashboards can be exported and imported via the GUI, Grafana GUI only allows export. Importing them is a little trickier and involves 
  1. Exporting the rules in the Alerting -> Alert rules tab, click 'Export rules' in the 'Grafana-managed' section. Export as a YAML file
  2. Put the contents of this YAML in a ConfigMap; see `alerts-test-configmap.yaml` in the alerts subdirectory for an example
  3. You need to make sure the Grafana alerts sidecar is in the helm chart; this sidecar scans for ConfigMaps
  4. Apply the configmap using `kubectl apply -f`
  5. Confirm the YAML file specified in the ConfifMap now exists in the Grafana instance
  ```
  kubectl exec deployment/prometheus-grafana -n monitoring -c grafana -- ls -la /etc/grafana/provisioning/alerting/
  ```
  6. Reload the provisioned files using the Grafana Admin HTTP API. This step is MANDATORY. On your local machine:
  ```
  kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
  curl -X POST -u admin:<PASSWORD> http://localhost:3000/api/admin/provisioning/alerting/reload
  ```
  If you have issues with the password, see the note above on Admin passwords.
  7. The Alerts should be present both in the Dashboards section (see the 'Alert rules' tab in the Alerts folder) and the Alert rules section


### Setting up Slack contact point
- If the contact point still exists for the alert rules specified in the config map, no need to do anything. Or, you could create a new contact point in the Grafana GUI and replace the `receiver` field in the config maps for the alert rules with the new name of the contact point.

#### UNDER CONSTRUCTION (THERE MAY BE BETTER WAYS TO STORE SLACK TOKENS AS SECRETS)
- However, you can also specify Slack contact points as config maps. See 'Configuring contact points' below for more info about configuring with Slack.
- To specify Slack contact point as config map: 
  1. Export contacts in Grafana GUI as YAML, put into config map, e.g. `contact-points.yaml` in this repo.
  1. Remove the slack bot token from configmap file, replace with $SLACK_BOT_TOKEN, and store it as a secret using `kubectl create secret generic slack-bot-token -n monitoring --from-literal=token='xoxb-TOKENTOKENTOKEN'`

### Deleting alert rules that have been provisioned as files via ConfigMaps

Deleting provisioned Alert rules is extremely [tedious](https://github.com/grafana/grafana/issues/67036):
  1. First, you need to delete the ConfigMaps that define the alert rules you want to delete
  2. As described [here](https://grafana.com/docs/grafana/latest/developers/http_api/alerting_provisioning/), deleting alert rules needs to be done by UID
  3. First get the UIDs, the following exports information that includes the UIDs in a JSON format
```
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
curl -u admin:<PASSWORD> http://localhost:3000/api/v1/provisioning/alert-rules
```
  4. Then create a ConfigMap specifying `deleteRules`, see an example in `alerts-test-delete-configmap.yaml`
  5. Apply the ConfigMap, reload using the Admin HTTP API as described above, and then delete the ConfigMap


# Configuring contact points
- For Slack integration, see (here)[https://grafana.com/docs/grafana/latest/alerting/configure-notifications/manage-contact-points/integrations/configure-slack/]
  - After their step 2, in the OAuth & Permissions section, make sure to 'Install to Enigma'


# Add ingress for grafana dahsboards
Flow:
Internet → nginx-ingress → prometheus-grafana service → Grafana pod

- Apply the grafana ingress
  - `kubectl apply -f grafana-ingress.yaml`

- confirm running + configured properly
  - `kubectl get ingress -A`

- to remove
  - `kubectl delete ingress grafana-ingress -n monitoring`

- test it
  - `curl -k -H "Host: grafana.atlab.stanford.edu" https://10.107.158.11/`

# Appendix

## Putting grafana dashboards in subfolders via configmaps
- For making grafana dashboards via config maps AND in subfolders, see [here](https://github.com/grafana/helm-charts/issues/526)
  - See `resources` subdir for an example of a configmap that creates a subfolder
- See [here](https://github.com/prometheus-community/helm-charts/issues/4493) for how to put default dashboards into a subfolder

## Deleting grafana dashboards that automatically come with helm installation
- these cannot be removed in the GUI
- You need to delete the [ConfigMaps](https://stackoverflow.com/questions/65308780/disable-default-dashboards-in-the-prometheus-community-helm-chart#:~:text=I%20was%20facing%20the%20same%20issue%20and%20the%20way%20I%20resolved%20it%20was%20to%20remove%20the%20respective%20config%20maps%20which%20have%20been%20generated%20by%20the%20kube%2Dprometheus%2Dstack%20helm%20chart.), you should see config maps with names corresponding to the porovisioned dashboards.