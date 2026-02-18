Once this config is deployed as a secret, have alertmanager reference it in the helm chart values file:

```
alertmanager:
  alertmanagerSpec:
    useExistingSecret: true
    configSecret: alertmanager-config
```

If useExistingSecret: true, then according to comments in default helm values file, "the config part will be ignored (including templateFiles) and the one in the secret will be used".

For configuring multiple Slack channels that defaults to 'default' if there are no matching channels, matched based on labels, you can do:

```
route:
  receiver: 'default'
  routes:
    - match:
        severity: critical
      receiver: 'slack-critical'
    - match:
        team: enigma
      receiver: 'slack-enigma'
receivers:
  - name: 'default'
    slack_configs:
      - channel: '#alerts'
  - name: 'slack-critical'
    slack_configs:
      - channel: '#alerts-critical'
  - name: 'slack-enigma'
    slack_configs:
      - channel: '#enigma-alerts'
```


# Using Vault to store secrets