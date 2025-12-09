# Makefile for managing CKAN deployment on Kubernetes using Helm.
# Supports site-specific overrides via site-values.yaml layered on top of values.yaml.

CONFIG_FILE ?= config.mk
-include $(CONFIG_FILE)

# Kubernetes context
DEFAULT_KUBE_CONTEXT := $(shell kubectl config current-context 2>/dev/null)
ifeq ($(strip $(KUBE_CONTEXT)),)
KUBE_CONTEXT := $(if $(DEFAULT_KUBE_CONTEXT),$(DEFAULT_KUBE_CONTEXT),microk8s)
endif

# Helm release and namespace configuration
HELM_RELEASE ?= ckan
NAMESPACE ?= ckan
CHART_DIR ?= .
KUBECTL ?= kubectl --context $(KUBE_CONTEXT) --namespace $(NAMESPACE)

# Values layering
VALUES_FILE ?= values.yaml
SITE_VALUES_FILE ?= site-values.yaml
# Overrides values from site-values.yaml
VALUES_ARGS := -f $(VALUES_FILE)
ifneq ($(wildcard $(SITE_VALUES_FILE)),)
VALUES_ARGS += -f $(SITE_VALUES_FILE)
endif

EXTRA_SET_ARGS := --set global.security.allowInsecureImages=true

.PHONY: update deploy uninstall status sysadmin-token

# Update Helm chart dependencies by downloading them into the charts/ directory
update:
	helm dependency update $(CHART_DIR)

# Deploy the Helm chart
deploy:
	@echo "Deploying $(HELM_RELEASE) to namespace $(NAMESPACE) (context: $(KUBE_CONTEXT))..."
	helm upgrade --cleanup-on-fail \
		--install $(HELM_RELEASE) $(CHART_DIR) \
		--kube-context $(KUBE_CONTEXT) \
		--namespace $(NAMESPACE) \
		--create-namespace \
		$(VALUES_ARGS) \
		$(EXTRA_SET_ARGS)

# Uninstall the Helm chart
uninstall:
	@echo "Uninstalling $(HELM_RELEASE) from namespace $(NAMESPACE)..."
	helm uninstall $(HELM_RELEASE) \
		--kube-context $(KUBE_CONTEXT) \
		--namespace $(NAMESPACE)

# Check the status of the Helm release
status:
	@echo "Checking status of $(HELM_RELEASE) in namespace $(NAMESPACE)..."
	helm status $(HELM_RELEASE) \
		--kube-context $(KUBE_CONTEXT) \
		--namespace $(NAMESPACE)


# CKAN CLI defaults for token generation
CKAN_INI_PATH ?= /app/production.ini

# Generate a sysadmin API token inside the CKAN pod and store it as a secret for downstream jobs
sysadmin-token:
	@echo "Generating CKAN sysadmin API token and applying it to namespace $(NAMESPACE)..."
	@POD=$$($(KUBECTL) get pods \
		-l "app.kubernetes.io/instance=ckan,app.kubernetes.io/name=ckan" \
		-o jsonpath='{range .items[?(@.status.phase=="Running")]}{.metadata.name}{"\n"}{end}' | head -n 1); \
	if [ -z "$$POD" ]; then \
		echo "No running CKAN pod found for release $(HELM_RELEASE) in namespace $(NAMESPACE). Deploy first with 'make deploy'."; \
		exit 1; \
	fi; \
	echo "Using pod: $$POD"; \
	TOKEN=$$($(KUBECTL) exec $$POD -- sh -c '\
		CKAN_USER_OVERRIDE="$(CKAN_USER)"; \
		export CKAN_INI="$(CKAN_INI_PATH)"; \
		CKAN_USER=$${CKAN_USER_OVERRIDE:-$$CKAN_SYSADMIN_NAME}; \
		ckan user token add "$$CKAN_USER" api_token_for_$$CKAN_USER | \
			tr -cd '\''\11\12\15\40-\176'\'' | \
			grep -Eo '\''eyJ[0-9a-zA-Z._-]{30,}'\'' | \
			head -n 1 \
	'); \
	if [ -z "$$TOKEN" ]; then \
		echo "Failed to create token via CKAN CLI; check CKAN logs and credentials."; \
		exit 1; \
	fi; \
	$(KUBECTL) create secret generic ckansysadminapitoken \
		--from-literal=sysadminApiToken=$$TOKEN \
		--dry-run=client -o yaml | $(KUBECTL) apply -f -; \
	echo "Updated secret ckansysadminapitoken in namespace $(NAMESPACE)."; \
	echo "Sysadmin API token: $$TOKEN"; \
