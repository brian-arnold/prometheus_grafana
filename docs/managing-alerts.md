# Alerts

Flow: **PrometheusRule → Prometheus → Alertmanager → Slack**

- **PrometheusRule** CRDs define the alert conditions (PromQL expressions). Prometheus automatically discovers these based on label selectors.
- **Prometheus** evaluates the rules and fires alerts to Alertmanager when conditions are met. 
- **Alertmanager** receives alerts and routes them based on its configuration, which is where you define Slack as a receiver. Alertmanager is automatically included and connected to prometheus within the kube-prometheus-stack.


## Creating alerts via PrometheusRule CRD

Here is a simple example of an alert for overheating GPUs:

```
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: gpu-alerts
  namespace: monitoring
  labels:
    release: prometheus  
spec:
  groups:
    - name: gpu.rules
      rules:
        - alert: GPUHighTemp
          expr: DCGM_FI_DEV_GPU_TEMP >= 92
          for: 1m
          labels:
            severity: critical
            team: enigma
          annotations:
            summary: "Node {{ $labels.Hostname }} has high GPU temp"
            description: "GPU {{ $labels.gpu }} on {{ $labels.Hostname }} has temp {{ $value }}C"
```

- `metadata.labels` needs to be `release: prometheus` in order for prometheus to detect it.

- `spec.groups.name.rules.alert.labels` dictate which slack channel the alert gets routed to (see below). A severity of critical gets sent to the `critical` channel, warning to the `warning` channel. Another label of `team: enigma` is also used to distinguish rules we want to get sent to slack from those that may have come provisioned with the kube-prometheus stack, or other rules we may want to still see in the prometheus/alertmanager GUI but not in slack.

# Alertmanager

To configure AlertManager for slack integration, there is a config section in the Helm chart that details which alerts get sent to which slack channels, and a bot token is needed. This config section is too long to put here, but see an example within this repo (TODO: SPECIFY THIS LOCATION WHEN FINALIZED).

## How to get a slack token.

Following [this tutorial](https://docs.slack.dev/tools/python-slack-sdk/tutorial/uploading-files/), 
1. Create a Slack app and install it in the workspace.
2. Go to "OAuth & Permissions" section, scroll down to Scopes -> Bot Token Scopes, and add the `chat:write` OAuth Scope from the drop down menu.
3. Go to "Install App" section, and install the app to the work space.
4. After this you should see a new OAuth Token. Copy this and save it.
5. Create a channel in slack
6. Once created, go to the message bar and type @AlertManager, or whatever name you chose for your bot, press enter, and then press the invite button to invite the bot to the channel.

This bot token can be used for multiple slack channels. Just put it in the appropriate place in the config section of the helm chart.

