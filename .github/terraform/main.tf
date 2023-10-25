terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "5.27.0"
    }
  }
}

provider "github" {
  owner = "stackturing"
}

resource "github_branch_protection_v3" "repository" {
  repository                      = "template"
  branch                          = "main"
  enforce_admins                  = true
  require_conversation_resolution = true

  required_pull_request_reviews {
    dismiss_stale_reviews      = true
    require_code_owner_reviews = true
  }
}
