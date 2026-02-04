# Add Ingress for Grafana Dashboards

Flow:
Internet → nginx-ingress → prometheus-grafana service → Grafana pod

While we could make these ingress resources separately and apply them outselves, we have since moved this information into the helm chart itself, which supports an ingress field for each of the apps: Prometheus, Alertmanager, Grafana. Please see the helm chart values file for more information.
