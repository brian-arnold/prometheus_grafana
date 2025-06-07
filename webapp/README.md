Flow:
Internet → nginx-ingress → prometheus-grafana service → Grafana pod


`kubectl apply -f grafana-ingress.yaml`

# confirm running + configured properly
`kubectl get ingress -A`

# remove
`kubectl delete ingress grafana-ingress -n monitoring`

# test

`curl -k -H "Host: grafana.atlab.stanford.edu" https://10.107.158.11/`