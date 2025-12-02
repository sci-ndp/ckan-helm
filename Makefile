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

# Values layering
VALUES_FILE ?= values.yaml
SITE_VALUES_FILE ?= site-values.yaml
# Overrides values from site-values.yaml
VALUES_ARGS := -f $(VALUES_FILE)
ifneq ($(wildcard $(SITE_VALUES_FILE)),)
VALUES_ARGS += -f $(SITE_VALUES_FILE)
endif

EXTRA_SET_ARGS := --set global.security.allowInsecureImages=true

.PHONY: update deploy uninstall status

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
