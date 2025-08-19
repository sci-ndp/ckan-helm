# makefile for managing ckan deployment on k8s using helm

# variables
kube-context := arn:aws:eks:us-west-2:515966508187:cluster/scidx # k8s cluster context
helm-release := ckan # Name of the helm release
ns := ckan
folder := . # Path to the helm chart dir

# phony targets
.PHONY: update deploy uninstall status


# updates helm chart dependencies by downloading them into the charts/ directory
update:
	helm dependency update $(folder)

# deploy the helm chart
deploy:
	helm upgrade --cleanup-on-fail \
		--install $(helm-release) $(folder) \
		--namespace $(ns) \
		--create-namespace

# uninstall the helm chart
uninstall:
	helm uninstall $(helm-release) \
		--kube-context $(kube-context) \
		--namespace $(ns)

# check the status of the helm release
status:
	helm status $(helm-release) \
		--kube-context $(kube-context) \
		--namespace $(ns)