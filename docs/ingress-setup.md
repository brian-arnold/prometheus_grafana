# Add Ingress for Grafana Dashboards

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
