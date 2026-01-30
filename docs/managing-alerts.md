# Managing Alert Rules as Files

### Exporting/importing alert rules

Although dashboards can be exported and imported via the GUI, Grafana GUI only allows export. Importing them is a little trickier and involves 
  1. Exporting the rules in the Alerting -> Alert rules tab, click 'Export rules' in the 'Grafana-managed' section. Export as a YAML file
  2. Put the contents of this YAML in a ConfigMap; see `alerts-test-configmap.yaml` in the alerts subdirectory for an example
  3. You need to make sure the Grafana alerts sidecar is in the helm chart; this sidecar scans for ConfigMaps
  4. Apply the configmap using `kubectl apply -f`
  5. Confirm the YAML file specified in the ConfifMap now exists in the Grafana instance
  ```
  kubectl exec deployment/prometheus-grafana -n monitoring -c grafana -- ls -la /etc/grafana/provisioning/alerting/
  ```
  6. Reload the provisioned files using the Grafana Admin HTTP API. This step is MANDATORY. On your local machine:
  ```
  kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
  curl -X POST -u admin:<PASSWORD> http://localhost:3000/api/admin/provisioning/alerting/reload
  ```
  If you have issues with the password, see the note on Admin passwords in the main README.
  7. The Alerts should be present both in the Dashboards section (see the 'Alert rules' tab in the Alerts folder) and the Alert rules section


### Setting up Slack contact point
- If the contact point still exists for the alert rules specified in the config map, no need to do anything. Or, you could create a new contact point in the Grafana GUI and replace the `receiver` field in the config maps for the alert rules with the new name of the contact point.

#### UNDER CONSTRUCTION (THERE MAY BE BETTER WAYS TO STORE SLACK TOKENS AS SECRETS)
- However, you can also specify Slack contact points as config maps. See 'Configuring contact points' below for more info about configuring with Slack.
- To specify Slack contact point as config map: 
  1. Export contacts in Grafana GUI as YAML, put into config map, e.g. `contact-points.yaml` in this repo.
  1. Remove the slack bot token from configmap file, replace with $SLACK_BOT_TOKEN, and store it as a secret using `kubectl create secret generic slack-bot-token -n monitoring --from-literal=token='xoxb-TOKENTOKENTOKEN'`

### Deleting alert rules that have been provisioned as files via ConfigMaps

Deleting provisioned Alert rules is extremely [tedious](https://github.com/grafana/grafana/issues/67036):
  1. First, you need to delete the ConfigMaps that define the alert rules you want to delete
  2. As described [here](https://grafana.com/docs/grafana/latest/developers/http_api/alerting_provisioning/), deleting alert rules needs to be done by UID
  3. First get the UIDs, the following exports information that includes the UIDs in a JSON format
```
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
curl -u admin:<PASSWORD> http://localhost:3000/api/v1/provisioning/alert-rules
```
  4. Then create a ConfigMap specifying `deleteRules`, see an example in `alerts-test-delete-configmap.yaml`
  5. Apply the ConfigMap, reload using the Admin HTTP API as described above, and then delete the ConfigMap


## Configuring contact points
- For Slack integration, see (here)[https://grafana.com/docs/grafana/latest/alerting/configure-notifications/manage-contact-points/integrations/configure-slack/]
  - After their step 2, in the OAuth & Permissions section, make sure to 'Install to Enigma'
