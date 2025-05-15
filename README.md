# Installation

- add prometheus helm repo and update
    - `helm repo add prometheus-community https://prometheus-community.github.io/helm-charts`
    - `helm repo update`
- create monitoring namespace
    - `kubectl create namespace monitoring`
- create PV and storage classes, apply file
    - `kubectl apply -f persistentVolume_StorageClass.yaml`
    - see below for this file
- check that it has been created
    - `kubectl get pv`
- helm install kube-prom-stack, using `values.yaml` file to have helm create PersistentVolumeClaims for the PVs based on the storage classes
    - `helm install prometheus prometheus-community/kube-prometheus-stack -f values.yaml --namespace monitoring`
    - note that this also creates an additional servicemonitor, explained later

### persistentVolume_StorageClass.yaml

```
# Create a PersistentVolume for Prometheus
apiVersion: v1
kind: PersistentVolume
metadata:
  name: prometheus-pv
spec:
  capacity:
    storage: 50Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: prometheus-storage
  hostPath:
    path: "/mnt/lab/k8s_apps/prometheus"
    type: DirectoryOrCreate

# Create a PersistentVolume for Grafana
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: grafana-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: grafana-storage  # Custom storage class name
  hostPath:
    path: "/mnt/lab/k8s_apps/grafana"
    type: DirectoryOrCreate
  
# Create StorageClass for Prometheus and Grafana
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: prometheus-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: Immediate # ensures the volumes are bound immediately when persistent volume claims are created, as opposed to waiting for a pod to be scheduled
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: grafana-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: Immediate
```

### values.yaml

```
prometheus:
  prometheusSpec:
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: prometheus-storage
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 50Gi
    # add additional serive monitor to allow prometheus to scrape metrics from nvidia-dcgm-exporter
    additionalServiceMonitors:
      - name: nvidia-dcgm-exporter
        selector:
          matchLabels:
            app: nvidia-dcgm-exporter  # Adjust this to match your service's labels
        namespaceSelector:
          matchNames:
            - gpu-operator
        endpoints:
          - port: gpu-metrics
            interval: 15s

grafana:
  persistence:
    enabled: true
    storageClassName: grafana-storage
    size: 10Gi
```



