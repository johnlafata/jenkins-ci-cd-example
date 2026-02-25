# Cloud Foundry Space Module
# Provisions a CF space with optional space quota and isolation segment

terraform {
  required_providers {
    cloudfoundry = {
      source  = "cloudfoundry/cloudfoundry"
      version = "~> 0.53"
    }
  }
}

variable "space_name" {
  description = "Name of the Cloud Foundry space"
  type        = string
}

variable "org_id" {
  description = "ID of the parent org"
  type        = string
}

variable "isolation_segment_id" {
  description = "ID of the isolation segment to associate (optional)"
  type        = string
  default     = null
}

variable "space_quota" {
  description = "Space quota definition"
  type = object({
    name            = string
    total_memory    = number  # in MB
    instance_memory = number  # in MB, -1 for unlimited
    total_routes    = number
    total_services  = number
  })
  default = null
}

variable "developers" {
  description = "List of developer usernames to add to the space"
  type        = list(string)
  default     = []
}

variable "managers" {
  description = "List of manager usernames to add to the space"
  type        = list(string)
  default     = []
}

resource "cloudfoundry_space_quota" "quota" {
  count = var.space_quota != null ? 1 : 0

  name            = var.space_quota.name
  org             = var.org_id
  total_memory    = var.space_quota.total_memory
  instance_memory = var.space_quota.instance_memory
  total_routes    = var.space_quota.total_routes
  total_services  = var.space_quota.total_services
}

resource "cloudfoundry_space" "space" {
  name = var.space_name
  org  = var.org_id

  quota             = var.space_quota != null ? cloudfoundry_space_quota.quota[0].id : null
  isolation_segment = var.isolation_segment_id
}

resource "cloudfoundry_space_users" "users" {
  space      = cloudfoundry_space.space.id
  managers   = var.managers
  developers = var.developers
}

output "space_id" {
  value = cloudfoundry_space.space.id
}

output "space_name" {
  value = cloudfoundry_space.space.name
}
