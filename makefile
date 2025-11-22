CLUSTER_NAME ?= demo-cluster
PROM_STACK_NS ?= monitoring
ARGO_NS ?= argocd

.PHONY: all cluster install ingress argocd prometheus app destroy

all: cluster ingress argocd prometheus app 

cluster:
	@echo "🔎 Checking for existing k3d cluster: $(CLUSTER_NAME)..."
	@if k3d cluster list | grep "$(CLUSTER_NAME)"; then \
		echo "✅ Cluster '$(CLUSTER_NAME)' already exists. Skipping creation."; \
	else \
		echo "🔥 Creating k3d cluster: $(CLUSTER_NAME)"; \
		k3d cluster create --config k3d-config.yaml; \
	fi                                                                                                                              

ingress:
	@echo "🌐 Installing NGINX Ingress Controller"
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml

argocd:
	@echo "🚀 Installing ArgoCD"
	kubectl create namespace $(ARGO_NS) --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -n $(ARGO_NS) -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

	@echo "⏳ Waiting for ArgoCD to be ready..."
	kubectl wait --for=condition=Available deployment/argocd-server -n $(ARGO_NS) --timeout=300s

	@echo "🔍 Checking for ArgoCD CLI..."
		@if ! command -v argocd >/dev/null 2>&1; then \
			echo "ArgoCD CLI not found. Attempting install via Brew..."; \
			if command -v brew >/dev/null 2>&1; then \
				brew install argocd; \
			else \
				echo "❌ Error: 'argocd' CLI not found and 'brew' is missing. Please install argocd CLI manually."; \
				exit 1; \
			fi \
		else \
			echo "✅ ArgoCD CLI is already installed."; \
		fi

	@echo "🔐 Logging into ArgoCD"
	argocd login --core

prometheus:
	@echo "📈 Installing Prometheus Stack"
	kubectl create namespace $(PROM_STACK_NS) --dry-run=client -o yaml | kubectl apply -f -
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo update
	helm upgrade --install monitoring prometheus-community/kube-prometheus-stack -n $(PROM_STACK_NS) -f monitoring.yaml
app:
	@echo "📦 Deploying the demo application via ArgoCD"
	kubectl apply -f argo-app.yaml

destroy:
	@echo "🧨 Deleting cluster"
	k3d cluster delete $(CLUSTER_NAME)
