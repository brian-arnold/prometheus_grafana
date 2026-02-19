# Add Ingress for Grafana Dashboards

Flow:
Internet → nginx-ingress → prometheus-grafana service → Grafana pod

While we could make these ingress resources separately and apply them ourselves, we have since moved this information into the helm chart itself. The `helm_values_files/values.yaml` file contains an `ingress:` block under each of the three top-level sections:

- `prometheus.ingress` — exposes the Prometheus UI at `prometheus.enigmatic.stanford.edu`
- `grafana.ingress` — exposes Grafana at `grafana.enigmatic.stanford.edu`
- `alertmanager.alertmanagerSpec` / `alertmanager.ingress` — exposes Alertmanager at `alertmanager.enigmatic.stanford.edu`

All three are configured with:
- `ingressClassName: nginx`
- SSL redirect and TLS termination via cert-manager (`letsencrypt` cluster issuer)
- Prometheus and Alertmanager additionally use OAuth2 proxy authentication (`gate.enigmatic.stanford.edu`)
