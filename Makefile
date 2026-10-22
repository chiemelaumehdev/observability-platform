AWS_PROFILE ?= observability
AWS_REGION  ?= us-east-1
ENV         ?= prod

TF_DIR := terraform/envs/$(ENV)

.PHONY: help
help:
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-22s %s\n", $$1, $$2}'

.PHONY: pre-commit
pre-commit: ## Install and run pre-commit against all files
	pre-commit install
	pre-commit run --all-files

.PHONY: tf-init
tf-init: ## Initialize Terraform with the environment backend
	cd $(TF_DIR) && terraform init -backend-config=backend.hcl -reconfigure

.PHONY: tf-fmt
tf-fmt: ## Format all Terraform files
	terraform fmt -recursive terraform/

.PHONY: tf-validate
tf-validate: ## Validate the current environment
	cd $(TF_DIR) && terraform validate

.PHONY: tf-plan
tf-plan: ## Plan the current environment, writing to plan.tfplan
	cd $(TF_DIR) && terraform plan -out plan.tfplan

.PHONY: tf-apply
tf-apply: ## Apply the planned changes
	cd $(TF_DIR) && terraform apply plan.tfplan

.PHONY: tf-destroy
tf-destroy: ## Destroy the environment. Interactive.
	cd $(TF_DIR) && terraform destroy

.PHONY: kubeconfig
kubeconfig: ## Write kubeconfig for the observability EKS cluster
	aws eks update-kubeconfig \
	  --name observability-eks \
	  --region $(AWS_REGION) \
	  --profile $(AWS_PROFILE) \
	  --alias observability

.PHONY: argocd-port-forward
argocd-port-forward: ## Open the Argo CD UI on localhost:8080
	kubectl -n argocd port-forward svc/argocd-server 8080:443

.PHONY: grafana-port-forward
grafana-port-forward: ## Open Grafana on localhost:3000
	kubectl -n observability port-forward svc/grafana 3000:80

.PHONY: helm-lint
helm-lint: ## Lint every Helm values file
	@for f in $$(find clusters -name 'values*.yaml'); do \
	  echo "=== $$f ==="; \
	  helm lint --values $$f --strict || exit 1; \
	done

.PHONY: bootstrap
bootstrap: ## Run the full cluster bootstrap script
	./scripts/bootstrap.sh

.PHONY: teardown-nodes
teardown-nodes: ## Destroy only the EKS node group (keeps control plane and storage)
	./scripts/teardown.sh --node-group-only

.PHONY: teardown-full
teardown-full: ## Destroy the full environment
	./scripts/teardown.sh --full
