CLUSTER_NAME ?= demo-cluster
PROM_STACK_NS ?= monitoring
ARGO_NS ?= argocd
APP_NS ?= demo

.PHONY: all cluster install ingress argocd monitoring app destroy

all: cluster ingress argocd monitoring app 

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
	
	@echo "🛑 Stopping any existing ArgoCD port-forward"
	@pkill -f "kubectl port-forward svc/argocd-server" >/dev/null 2>&1 || true

	@echo "🔌 Starting ArgoCD port-forward in background..."
	(kubectl port-forward svc/argocd-server -n $(ARGO_NS) 8080:80 >/dev/null 2>&1 &)

	@echo "🔐 Logging into ArgoCD..."
	kubectl -n $(ARGO_NS) get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode > /tmp/argocd_pass.txt
	argocd login localhost:8080 --username admin --password $$(cat /tmp/argocd_pass.txt) --insecure

monitoring:
	@echo "📈 Installing Prometheus Stack"
	kubectl create namespace $(PROM_STACK_NS) --dry-run=client -o yaml | kubectl apply -f -
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo update
	helm upgrade --install monitoring prometheus-community/kube-prometheus-stack -n $(PROM_STACK_NS) -f monitoring.yaml

	@echo "⏳ Waiting for Grafana pod to be ready..."
	kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=grafana -n $(PROM_STACK_NS) --timeout=300s

	@echo "🔐 Grafana admin password:"
	kubectl get secret --namespace $(PROM_STACK_NS) -l app.kubernetes.io/component=admin-secret -o jsonpath="{.items[0].data.admin-password}" | base64 --decode ; echo

	@echo "🛑 Stopping any existing Grafana port-forward"
	@pkill -f "kubectl port-forward svc/monitoring-grafana" >/dev/null 2>&1 || true

	@echo "🚀 Port-forwarding Grafana to http://localhost:3000"
	(kubectl port-forward svc/monitoring-grafana 3000:80 -n $(PROM_STACK_NS) >/dev/null 2>&1 &)

app:
	@echo "📦 Deploying the demo application via ArgoCD"
	kubectl create namespace $(APP_NS) --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -f argo-app.yaml
	kubectl wait --for=condition=Available deployment/demo -n $(APP_NS) --timeout=300s

	@echo "🛑 Stopping any existing application port-forward"
	@pkill -f "kubectl port-forward svc/$(APP_NS)" >/dev/null 2>&1 || true

	@echo "🚀 Port-forwarding application to http://localhost:8090"
	(kubectl port-forward svc/$(APP_NS) 8090:80 -n $(APP_NS) >/dev/null 2>&1 &)

	@echo "🎉 Grafana UI available at: http://localhost:3000"
	@echo "🎉 ArgoCD UI available at: http://localhost:8080"
	@echo "🎉 Application UI available at: http://localhost:8090"

destroy:
	@echo "🧨 Deleting cluster"
	k3d cluster delete $(CLUSTER_NAME)
