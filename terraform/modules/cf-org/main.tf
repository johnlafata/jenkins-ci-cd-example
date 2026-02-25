# Cloud Foundry Org Module
# Provisions a CF org with optional quota definition

terraform {
  required_providers {
    cloudfoundry = {
      source  = "cloudfoundry/cloudfoundry"
      version = "~> 0.53"
    }
  }
}

variable "org_name" {
  description = "Name of the Cloud Foundry org"
  type        = string
}

variable "org_quota" {
  description = "Org quota definition"
  type = object({
    name                     = string
    total_memory             = number  # in MB
    instance_memory          = number  # in MB, -1 for unlimited
    total_routes             = number
    total_services           = number
    total_app_instances      = number
    allow_paid_service_plans = bool
  })
  default = null
}

resource "cloudfoundry_org_quota" "quota" {
  count = var.org_quota != null ? 1 : 0

  name                     = var.org_quota.name
  total_memory             = var.org_quota.total_memory
  instance_memory          = var.org_quota.instance_memory
  total_routes             = var.org_quota.total_routes
  total_services           = var.org_quota.total_services
  total_app_instances      = var.org_quota.total_app_instances
  allow_paid_service_plans = var.org_quota.allow_paid_service_plans
}

resource "cloudfoundry_org" "org" {
  name  = var.org_name
  quota = var.org_quota != null ? cloudfoundry_org_quota.quota[0].id : null
}

output "org_id" {
  value = cloudfoundry_org.org.id
}

output "org_name" {
  value = cloudfoundry_org.org.name
}
