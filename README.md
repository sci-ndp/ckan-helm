CKAN Helm (SciDx fork)
====================

This repo packages the upstream [Keitaro CKAN Helm chart](https://github.com/keitaroinc/ckan-helm) and adds a `Makefile` so SciDx teams can deploy a complete CKAN stack with consistent defaults. The chart bundles CKAN plus optional dependencies (PostgreSQL, SOLR, Redis, Datapusher) and can be tailored through custom overrides(`site-values.yaml`) or optionally `values.yaml` if needed.

## Prerequisites
- A reachable Kubernetes cluster and a configured `kubectl` context (the Makefile falls back to your current context)
- [Helm 3](https://helm.sh/docs/intro/install/) and `make` installed locally
- Permission to create namespaces, deployments, and persistent volumes in the target cluster

## **Installation**
1. #### **Copy default make config**, all make targets share the same settings:
   ```bash
   cp config.example.mk config.mk
   ```

   >`KUBE_CONTEXT` defaults to your current kubectl context (or `microk8s` if none); override in `config.mk` as needed.

    Key settings in `config.mk`, change as needed:
    - `KUBE_CONTEXT`: kube context to target (overrides current-context).
    - `NAMESPACE`: namespace for CKAN stack.
    - `RELEASE_NAME`: Helm release name details for the CKAN stack.

2. #### **Centralize Site Overrides**
   ```bash
   cp site-values.example.yaml site-values.yaml
   ```
   Edit `site-values.yaml` for your environment:
   - `ckan.siteTitle`, `ckan.siteUrl`: public URL.
   - `ckan.sysadminName`, `ckan.sysadminEmail`, `ckan.sysadminPassword`: Initial admin identity and password.
   - `ingress.className`: IngressClass to use (e.g., `public`, `nginx`).
   - `ingress.hosts[].host`: Hostname served by the ingress.
   - `ingress.hosts[].paths[].path`: Keep `/ckan(/|$)(.*)` or another path that routes traffic to CKAN; required for a valid ingress rule, no need to change.
   - `pvc.storageClassName`, `pvc.size`: Storage class and size for CKAN data PVC.

3. #### **Update Helm Chart Dependencies:** Fetch and update Helm chart dependencies listed in `Chart.yaml`
    ```bash
    make update
    ```

5. #### **Deploy CKAN:** Install/upgrade CKAN in the target namespace using Helm
    ```bash
    make deploy
    ```

## **Access** your CKAN
`http://<ingress-host>/ckan`

## **Sysadmin API token**
Generate a fresh API token for the sysadmin user from the CKAN UI, then update your overrides and secret so the deployment picks it up:
1. In CKAN, sign in as the sysadmin and create a new API token.
2. Update the CKAN API token:
   ```bash
   kubectl -n <namespace> create secret generic ckansysadminapitoken \
     --from-literal=sysadminApiToken=<generated_api_token> \
     --dry-run=client -o yaml | kubectl apply -f -
   ```
   Replace `<namespace>` with your target namespace, and `<generated_api_token>` with the new token from step 1.

## Troubleshooting
- If `make deploy` fails, re-run `make status` and inspect failed hooks or pods, then review pod logs via `kubectl logs`.
- Namespace already exists errors usually mean a partial install; run `make uninstall` before retrying.
- Persistent data lives in PVCs that Helm does not delete automatically. Clear them explicitly when resetting an environment.

## Next Steps
Go back to [**SciDx Kubernetes Document**](https://github.com/sci-ndp/scidx-k8s/blob/main/README.md#deploy-ckan) for more details about the overall Kubernetes setup for SciDx service.

## Upstream reference
The upstream README contains extensive configuration tables and background information about each value exposed by the chart. Refer to:
- [Upstream README](https://github.com/keitaroinc/ckan-helm#readme) for a complete list of tunables and dependency charts.
- `values.yaml` in this repository for SciDx defaults and the most relevant value overrides.

For convenience, the upstream "Chart Requirements" overview is reproduced below; consult the upstream documentation for version updates:

| Repository | Name | Version |
|------------|------|---------|
| https://charts.bitnami.com/bitnami | postgresql | 16.7.27 |
| https://charts.bitnami.com/bitnami | redis | 23.0.2 |
| https://charts.bitnami.com/bitnami | solr | 9.6.10 |
