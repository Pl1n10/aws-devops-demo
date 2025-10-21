.PHONY: help init validate plan apply destroy test build run-local deploy chaos logs ssh dashboard outputs clean

APP_NAME := devops-api
AWS_REGION := eu-west-1
TERRAFORM_DIR := infra/terraform
IMAGE_REPO := ghcr.io/yourusername/$(APP_NAME)
IMAGE_TAG := latest

help:
	@echo "AWS DevOps Demo - Commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "%-18s %s\n", $$1, $$2}'

init: ## Initialize Terraform
	cd $(TERRAFORM_DIR) && terraform init

validate: ## Validate Terraform
	cd $(TERRAFORM_DIR) && terraform fmt -recursive && terraform validate

plan: ## Terraform plan
	cd $(TERRAFORM_DIR) && terraform plan

apply: ## Terraform apply
	cd $(TERRAFORM_DIR) && terraform apply -auto-approve

destroy: ## Destroy infra
	cd $(TERRAFORM_DIR) && terraform destroy -auto-approve

test: ## Run tests
	cd app && python -m pytest -v

build: ## Build Docker image
	docker build -t $(IMAGE_REPO):$(IMAGE_TAG) app/

run-local: ## Run locally
	docker run -p 8080:80 --rm $(IMAGE_REPO):$(IMAGE_TAG)

deploy: ## Deploy via script
	./scripts/deploy.sh

outputs: ## Show TF outputs
	cd $(TERRAFORM_DIR) && terraform output

logs: ## Tail app logs
	@IP=$$(cd $(TERRAFORM_DIR) && terraform output -raw instance_public_ip); \
	ssh -i ~/.ssh/ec2-key.pem ubuntu@$$IP "tail -f /var/log/app/app.log"

ssh: ## SSH to instance
	@IP=$$(cd $(TERRAFORM_DIR) && terraform output -raw instance_public_ip); \
	ssh -i ~/.ssh/ec2-key.pem ubuntu@$$IP

dashboard: ## Open CloudWatch dashboard
	@URL=$$(cd $(TERRAFORM_DIR) && terraform output -raw cloudwatch_dashboard_url); \
	xdg-open $$URL 2>/dev/null || open $$URL 2>/dev/null || echo "Dashboard URL: $$URL"

clean: ## Cleanup local
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete
	docker system prune -f
