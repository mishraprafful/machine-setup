##@ General

.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Development

install: ## Install dependencies.
	pip3 install --upgrade pip
	pip3 install ansible ansible-lint
	ansible-galaxy install -r requirements.yml

lint: ## Perform linting.
	ansible-lint --write

check: ## Perform static syntax check.
	ansible-playbook local.yml --syntax-check
	
##@ Setup a Machine

local: ## Setup local machine.
	ansible-playbook local.yml -K
