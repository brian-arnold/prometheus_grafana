# Background
This prometheus/grafana stack deployment is simple. Prometheus seems to require local storage, so here we deploy a single instance of prometheus and grafana on a specific node (at-compute010) and use subdirectories within /mnt/md0 for these apps to store their data. If these pods ever crash, we have them deploy to the same node so that they still have access to their data within node-specific /mnt/md0. 


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

# Additional configuration

The kube-prometheus-stack provides infrastructure monitoring for all pods via kubelet, but some application metrics require custom configuration.

### kube-controller-manager
Kube-controller-manager is a collection of different Kubernetes controllers, all of them included in a binary and running permanently in a loop. Read more [here](https://www.sysdig.com/blog/how-to-monitor-kube-controller-manager).

By default, the kube-controller-manager has a bind address of 127.0.0.1 such that only pods on it's local network (machine hosting control plane) can reach it, so in order for the prometheus server to scrape it, change to 0.0.0.0 by SSH'ing into the control plane (at-kubemaster1) and change the appropriate field:

```
sudo vi /etc/kubernetes/manifests/kube-controller-manager.yaml
```

and change `--bind-address=127.0.0.1` to `--bind-address=0.0.0.0`.

### kube-scheduler

The kubernetes scheduler is a control plane component responsible for assigning newly created pods to available nodes. It continuously monitors for pods that do not have a node assigned and determines the most suitable node for them.

Like the controller manager, the default kube-scheduler pod has a bind address of 127.0.0.1 such that it's only listening on local host and unreachable by the prometheus server for metric scraping. To fix, SSH into the control plane and use

```
sudo vi /etc/kubernetes/manifests/kube-scheduler.yaml
```

to change `--bind-address=127.0.0.1` to `--bind-address=0.0.0.0`.
### kube-proxy

kube-proxy runs as a daemonset on the cluster, one pod per node, and plays a crucial role in implementing the kubernetes Service concept, ensuring that network requests to services are correctly routed to the appropriate pods.

Executing kubectl describe daemonsets kube-proxy -n kube-system seemed to show little configuration info but I noticed under the Volumes section it referred to a config map. Further executing kubectl describe cm kube-proxy -n kube-system shows a field metricsBindAddress: "", meaning metrics are disabled. To enable, this should be changed to metricsBindAddress: "0.0.0.0:10249" using
```
kubectl edit cm kube-proxy -n kube-system
```
then restarting the daemonset using 
```
kubectl rollout restart daemonset kube-proxy -n kube-system
```


### etcd
Etcd is an open-source, distributed key-value store that serves as the primary data store for Kubernetes. It's a critial component for maintaining the state and configuration of a kubernetes cluster.

Like the kube-controller-manager, the default etcd config has `--listen-metrics-urls=http://127.0.0.1:2381`, meaning it is only listening on localhost. Change this to `0.0.0.0:2381`.

### NVIDIA DCGM exporter
Added service monitor in values file.

### Ray
See [here](https://docs.ray.io/en/latest/cluster/kubernetes/k8s-ecosystem/prometheus-grafana.html#using-prometheus-and-grafana) for how to monitor Ray resources with prometheus and grafana.
- As suggested by the Ray [docs](https://docs.ray.io/en/latest/cluster/kubernetes/k8s-ecosystem/prometheus-grafana.html#using-prometheus-and-grafana) for setting up prometheus/grafana with k8s, apply the following pod monitors 
  - `kubectl apply -f ray_podmonitors.yaml`
- See docs in `ray_podmonitors.yaml` for more info.

### Velero

The Velero helm chart has the option to create a ServiceMonitor for prometheus to scrape. Please see the helm chart for more information. Briefly, you needed to specify in the chart that you wanted a service monitor created and to add the `release: prometheus` label since your instance of prometheus looks for service monitors with that label.

### DirectPV and Minio

#### DirectPV 

According to their docs, Both DirectPV and Minio are configured for prometheus via additional scrape configs, in the helm values file under `additionalScrapeConfigs` or `additionalScrapeConfigsSecret`. However, the option with secrets CANNOT be used with the other option; you can only use one or the other (see default values file for note on this). We thus need to use the secret option because we store a MinIO token.

See [here](https://github.com/minio/directpv/blob/master/docs/monitoring.md) for how to scrape directpv metrics with prometheus, but also see [here](https://docs.min.io/enterprise/aistor-volume-manager/concepts/metrics/), which shows that there may be fewer metrics supported.

Setting up for DirectPV was pretty straightforward as the scrape config they supply can be copy/pasted into the values file under additionalScrapeConfigs or into the secrets file, explained below.

#### MinIO
See [here](https://docs.min.io/community/minio-object-store/operations/monitoring/collect-minio-metrics-using-prometheus.html) for how to scrape metrics from MinIO.

Implementing the steps in the tutorial above:
1. Generate scrape config
  - In one terminal window run `kubectl run mc-test --image=minio/mc --rm -i --restart=Never --command -- sleep 300`
  - In another terminal window run
    - `kubectl exec -it mc-test -- mc alias set myminio https://minio.minio-tenant.svc.cluster.local:443 MINIO_ROOT_USER MINIO_ROOT_PASSWORD --insecure`
    - `kubectl exec -it mc-test -- mc admin prometheus generate myminio`
2. Put scrape config in the values file
  - The scrape config generated by the above command contains a `bearer_token` that shouldn't be stored on GitHub.
  - Instead I put the following in a file named `dpv-minio-scrape-config-w-token.yaml`, which is the output from the command above
  ```
  # scrape configs for MinIO
  - job_name: minio-job
    bearer_token: <TOKEN-OMITTED> 
    metrics_path: /minio/v2/metrics/cluster
    scheme: https
    # I added tls config skip verify
    tls_config:
      insecure_skip_verify: true
    static_configs:
    - targets: ['minio.minio-tenant.svc.cluster.local:443']

  # scrape configs for directpv
  - job_name: 'directpv-metrics'
    scheme: http
    metrics_path: /directpv/metrics
    authorization:
      credentials_file: /var/run/secrets/kubernetes.io/serviceaccount/token

    kubernetes_sd_configs:
    - role: pod

    relabel_configs:
    - source_labels: [__meta_kubernetes_namespace]
      regex: "directpv"
      action: keep
    - source_labels: [__meta_kubernetes_pod_controller_kind]
      regex: "DaemonSet"
      action: keep
    - source_labels: [__meta_kubernetes_pod_container_port_name]
      regex: "healthz"
      action: drop
      target_label: kubernetes_port_name

  - job_name: 'kubernetes-cadvisor'
    scheme: https
    metrics_path: /metrics/cadvisor
    tls_config:
      ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
      insecure_skip_verify: true
    authorization:
      credentials_file: /var/run/secrets/kubernetes.io/serviceaccount/token

    kubernetes_sd_configs:
    - role: node

    relabel_configs:
    - action: labelmap
      regex: __meta_kubernetes_node_label_(.+)
    - source_labels: [__meta_kubernetes_namespace]
      action: replace
      target_label: kubernetes_namespace
    - source_labels: [__meta_kubernetes_service_name]
      action: replace
      target_label: kubernetes_name    
  ```
  - Save this in a file called `dpv-minio-scrape-config-w-token.yaml` to store in a secret
  ```
  kubectl create secret generic additional-scrape-configs-dpv-minio \
  --from-file=prometheus-dpv-minio.yaml=dpv-minio-scrape-config-w-token.yaml \
  -n monitoring
  ```
  - Refer to prometheus-minio.yaml in additionalScrapeConfigsSecret in the values file (see values file)

# Change admin password
I've had better luck managing the admin password through this command compared to editing within the GUI, where I noticed it stoppped working (but this could have been due to upgrades), and if I get locked out I can just do the following:
```
kubectl exec -n monitoring deployment/prometheus-grafana -- grafana-cli admin reset-admin-password <PASSWORD> 
```

# Extra configuration
- 

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