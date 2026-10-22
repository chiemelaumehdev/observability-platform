#!/usr/bin/env bash
# bootstrap.sh — idempotent cluster bootstrap.
#
# Preconditions:
#   - Terraform in terraform/envs/prod has been applied
#   - AWS profile "observability" is configured
#   - kubectl, helm, argocd CLIs are installed
#
# Steps:
#   1. Write kubeconfig for observability-eks
#   2. Install Argo CD via its official manifest (one-time, hand-applied)
#   3. Apply the Argo CD root app, which pulls everything else from Git

set -euo pipefail

: "${AWS_PROFILE:=observability}"
: "${AWS_REGION:=us-east-1}"
: "${CLUSTER:=observability-eks}"
: "${REPO_URL:=https://github.com/chiemelaumehdev/observability-platform.git}"
: "${REPO_REVISION:=main}"

ARGOCD_VERSION="${ARGOCD_VERSION:-v2.13.1}"

info() { printf "\033[1;34m==> %s\033[0m\n" "$*"; }

info "Writing kubeconfig for ${CLUSTER}"
aws eks update-kubeconfig \
  --name "${CLUSTER}" \
  --region "${AWS_REGION}" \
  --profile "${AWS_PROFILE}" \
  --alias observability

info "Ensuring argocd namespace exists"
kubectl get namespace argocd >/dev/null 2>&1 || kubectl create namespace argocd

info "Installing Argo CD ${ARGOCD_VERSION}"
kubectl apply -n argocd \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

info "Waiting for Argo CD server to be Ready"
kubectl -n argocd rollout status deploy/argocd-server --timeout=5m

info "Applying root Argo CD Application"
kubectl apply -f "$(dirname "$0")/../clusters/observability/argocd/bootstrap/root-app.yaml"

info "Bootstrap complete. Monitor sync progress with:"
printf "  kubectl -n argocd get applications\n"
printf "  argocd app list\n"
