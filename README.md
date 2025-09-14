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

# Extra configuration
- The kube-prometheus-stack provides infrastructure monitoring for all pods via kubelet, but Ray application metrics require some custom configuration.
- As suggested by the Ray [docs](https://docs.ray.io/en/latest/cluster/kubernetes/k8s-ecosystem/prometheus-grafana.html#using-prometheus-and-grafana) for setting up prometheus/grafana with k8s, apply the following pod monitors 
  - `kubectl apply -f ray_podmonitors.yaml`
- See docs in `ray_podmonitors.yaml` for more info.

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


# Deleting grafana dashboards that automatically come with helm installation
- these cannot be removed in the GUI
- You need to delete the [ConfigMaps](https://stackoverflow.com/questions/65308780/disable-default-dashboards-in-the-prometheus-community-helm-chart#:~:text=I%20was%20facing%20the%20same%20issue%20and%20the%20way%20I%20resolved%20it%20was%20to%20remove%20the%20respective%20config%20maps%20which%20have%20been%20generated%20by%20the%20kube%2Dprometheus%2Dstack%20helm%20chart.), you should see config maps with names corresponding to the porovisioned dashboards.