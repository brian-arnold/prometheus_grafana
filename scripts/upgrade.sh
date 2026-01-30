# pin version to avoid unexpected surprises
helm upgrade \
prometheus \
prometheus-community/kube-prometheus-stack \
-f ../values.yaml \
--namespace monitoring \
--version 77.11.0