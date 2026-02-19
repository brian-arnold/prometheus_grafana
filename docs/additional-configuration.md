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

Like the kube-controller-manager, the default etcd config has `--listen-metrics-urls=http://127.0.0.1:2381`, meaning it is only listening on localhost. Change this to `0.0.0.0:2381` by logging into the control plane node and doing

```
sudo vi /etc/kubernetes/manifests/etcd.yaml
```

### NVIDIA DCGM exporter

Prometheus scrapes GPU metrics from the `nvidia-dcgm-exporter` (deployed by the GPU operator in the `gpu-operator` namespace) via an additional ServiceMonitor defined in `helm_values_files/values.yaml` under `prometheus.additionalServiceMonitors`. The ServiceMonitor selects services with the label `app: nvidia-dcgm-exporter` in the `gpu-operator` namespace and scrapes the `gpu-metrics` port every 15 seconds.

No manual steps are required beyond having the GPU operator (and its DCGM exporter) already running in the cluster.

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
# scrape configs for MinIO
- job_name: minio-job
  bearer_token: <OMITTED> 
  metrics_path: /minio/v2/metrics/cluster
  scheme: https
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
    regex: "metrics"
    action: keep

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