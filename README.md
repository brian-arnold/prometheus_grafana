# Prometheus/Grafana Stack for Kubernetes Monitoring

## Background
This prometheus/grafana stack deployment is simple. Prometheus seems to require local storage, so here we deploy a single instance of prometheus and grafana on a specific node (at-compute010) and use subdirectories within /mnt/md0 for these apps to store their data. If these pods ever crash, we have them deploy to the same node so that they still have access to their data within node-specific /mnt/md0.

## Installation
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


## Documentation

For detailed information on specific topics, see the documentation in the [docs](docs/) directory:

- **[Additional Configuration](docs/additional-configuration.md)** - Configure monitoring for specific Kubernetes components (kube-controller-manager, kube-scheduler, kube-proxy, etcd, NVIDIA DCGM exporter)
- **[Managing Alerts](docs/managing-alerts.md)** - Export/import alert rules, set up Slack notifications, and manage alert rules via ConfigMaps
- **[Dashboards and Alerts Workflow](docs/dashboards-and-alerts-workflow.md)** - Step-by-step workflows for creating and managing dashboards and alert rules
- **[Ingress Setup](docs/ingress-setup.md)** - Configure ingress to access Grafana dashboards externally
- **[Troubleshooting](docs/troubleshooting.md)** - Advanced topics including changing the admin password, subfolder configuration, and deleting default dashboards