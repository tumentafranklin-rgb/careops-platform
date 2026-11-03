terraform {
  required_version = ">= 1.17.0, < 2.0.0"

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

resource "local_file" "app_config" {
  filename        = "${path.module}/careops-config.json"
  file_permission = "0644"

  content = jsonencode({
    application = "careops-platform"
    environment = "development"
    version     = "v3"
  })
}