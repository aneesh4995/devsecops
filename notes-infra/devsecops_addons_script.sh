#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Script:      install-devsecops-addons.sh
# Purpose:     Add Kubernetes namespaces and install ArgoCD, Argo Rollouts,
#              OPA Gatekeeper, and Prometheus/Grafana via Helm.
# Reasoning:   Automate the manual Helm/kubectl steps so your cluster has:
#                1) ArgoCD for GitOps deployment
#                2) Argo Rollouts for progressive delivery
#                3) Gatekeeper for policy enforcement
#                4) Prometheus + Grafana for monitoring & alerting
# ==============================================================================

# Check dependencies
for cmd in kubectl helm; do
  if ! command -v $cmd &> /dev/null; then
    echo "❌ '$cmd' is required but not installed. Aborting." >&2
    exit 1
  fi
done

echo "✅ Prerequisites found: kubectl & helm"

# 1) Add Helm repositories
echo "⏳ Adding Helm repos..."
helm repo add argo https://argoproj.github.io/argo-helm           
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts 
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 
helm repo update
echo "✅ Helm repos added & updated"

# Helper function to create namespace if it doesn't exist
create_ns() {
  local ns="$1"
  if kubectl get ns "$ns" &> /dev/null; then
    echo "ℹ️  Namespace '$ns' already exists"
  else
    echo "⏳ Creating namespace '$ns'..."
    kubectl create namespace "$ns"
    echo "✅ Namespace '$ns' created"
  fi
}

# 2) Install ArgoCD (GitOps controller & UI)
create_ns argocd
if helm status argocd -n argocd &> /dev/null; then
  echo "ℹ️  ArgoCD already installed in 'argocd' namespace"
else
  echo "⏳ Installing ArgoCD..."
  helm install argocd argo/argo-cd -n argocd \
    --set server.service.type=LoadBalancer \
    --set server.ingress.enabled=false
  echo "✅ ArgoCD installed"
fi

# 3) Install Argo Rollouts (CRD + controller for blue/green & canaries)
create_ns argo-rollouts
if helm status argo-rollouts -n argo-rollouts &> /dev/null; then
  echo "ℹ️  Argo Rollouts already installed in 'argo-rollouts' namespace"
else
  echo "⏳ Installing Argo Rollouts..."
  helm install argo-rollouts argo/argo-rollouts -n argo-rollouts
  echo "✅ Argo Rollouts installed"
fi

# 4) Install OPA Gatekeeper (policy-as-code enforcement)
create_ns gatekeeper-system
if helm status gatekeeper -n gatekeeper-system &> /dev/null; then
  echo "ℹ️  Gatekeeper already installed in 'gatekeeper-system' namespace"
else
  echo "⏳ Installing OPA Gatekeeper..."
  helm install gatekeeper gatekeeper/gatekeeper -n gatekeeper-system \
    --set auditInterval=30s
  echo "✅ OPA Gatekeeper installed"
fi

# 5) Install Prometheus & Grafana (monitoring stack)
create_ns monitoring
if helm status prometheus -n monitoring &> /dev/null; then
  echo "ℹ️  Prometheus stack already installed in 'monitoring' namespace"
else
  echo "⏳ Installing Prometheus & Grafana..."
  helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring \
    --set grafana.service.type=LoadBalancer \
    --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
  echo "✅ Prometheus & Grafana installed"
fi

echo "🎉 All components installed successfully!"
