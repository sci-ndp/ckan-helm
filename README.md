CKAN Helm (SciDx fork)
====================

This repo packages the upstream [Keitaro CKAN Helm chart](https://github.com/keitaroinc/ckan-helm) and adds a `Makefile` so SciDx teams can deploy a complete CKAN stack with consistent defaults. The chart bundles CKAN plus optional dependencies (PostgreSQL, SOLR, Redis, Datapusher) and can be tailored through `values.yaml` or custom overrides.

## Prerequisites
- A reachable Kubernetes cluster and a configured `kubectl` context (defaults to `microk8s-202` in the Makefile)
- [Helm 3](https://helm.sh/docs/intro/install/) and `make` installed locally
- Permission to create namespaces, deployments, and persistent volumes in the target cluster

## Quick Start (Makefile workflow)
1. `make update` – pull the chart's dependency subcharts into `charts/`
2. Adjust `values.yaml` or prepare your own override file as needed
3. `make deploy` – run `helm upgrade --install` for release `ckan` in namespace `ckan`
4. `make status` – inspect the release once pods are running
5. `make uninstall` – remove the release when you are finished (PVCs may need manual cleanup)

All targets are idempotent; repeat `make deploy` after editing configuration to roll out changes.

## Make targets and knobs
- `make update` keeps dependency charts in sync with the versions pinned in `Chart.lock`.
- `make deploy` installs or upgrades the release. Override defaults by passing variables, for example:
  ```sh
  make deploy helm-release=ckan-staging ns=data-platform kube-context=staging
  ```
- `make status` surfaces the Helm release status to help troubleshoot failed hooks or pending pods.
- `make uninstall` removes the release from the target namespace. Delete PVCs manually if you want a clean slate: `kubectl delete pvc -n <ns> -l app=ckan`.

The Makefile exposes these variables (with defaults shown):

| Variable       | Default         | Purpose                              |
|----------------|-----------------|--------------------------------------|
| `helm-release` | `ckan`          | Name of the Helm release             |
| `ns`           | `ckan`          | Kubernetes namespace for the chart   |
| `kube-context` | `microk8s-202`  | `kubectl` context used by Helm       |
| `folder`       | `.`             | Chart directory passed to Helm       |

Because they are standard make variables, supply overrides on the command line (`make deploy ns=ckan-dev`). Edit the `Makefile` if you need to add flags such as `--values additional.yaml` or `--set` expressions.

## Customising the chart
- **values.yaml** – edit this file to enable/disable bundled services or to inject CKAN configuration values.
- **Separate overrides** – keep environment-specific files (e.g. `values.staging.yaml`) and either adjust the Makefile or call Helm directly via `helm upgrade --install ckan . -f values.staging.yaml`.
- **Existing infrastructure** – set `postgresql.enabled`, `redis.enabled`, etc., to `false` when pointing CKAN to managed services instead of the bundled dependencies.

## Repository layout
- `Chart.yaml`, `Chart.lock`, `charts/` – Helm metadata and vendored dependencies
- `templates/`, `values.yaml` – core CKAN chart templates and defaults
- `dependency-charts/`, `solr-init/` – helper charts and jobs used by the deployment
- `Makefile` – opinionated entry points for SciDx deployment.

## Troubleshooting
- If `make deploy` fails, re-run `make status` and inspect failed hooks or pods, then review pod logs via `kubectl logs`.
- Namespace already exists errors usually mean a partial install; run `make uninstall` before retrying.
- Persistent data lives in PVCs that Helm does not delete automatically. Clear them explicitly when resetting an environment.

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

