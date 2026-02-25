# Cloud Foundry Application Security Group Module
# Creates ASGs and binds them to spaces

terraform {
  required_providers {
    cloudfoundry = {
      source  = "cloudfoundry/cloudfoundry"
      version = "~> 0.53"
    }
  }
}

variable "asg_name" {
  description = "Name of the Application Security Group"
  type        = string
}

variable "rules" {
  description = "List of ASG rules"
  type = list(object({
    protocol    = string       # tcp, udp, icmp, all
    destination = string       # CIDR or IP range
    ports       = optional(string)  # e.g., "1433" or "8080-8090"
    description = optional(string)
  }))
}

variable "running_space_ids" {
  description = "List of space IDs to bind this ASG for running apps"
  type        = list(string)
  default     = []
}

variable "staging_space_ids" {
  description = "List of space IDs to bind this ASG for staging apps"
  type        = list(string)
  default     = []
}

resource "cloudfoundry_asg" "asg" {
  name = var.asg_name

  dynamic "rule" {
    for_each = var.rules
    content {
      protocol    = rule.value.protocol
      destination = rule.value.destination
      ports       = rule.value.ports
      description = rule.value.description
    }
  }
}

# Bind ASG to spaces for running applications
resource "cloudfoundry_asg_space_binding" "running" {
  for_each = toset(var.running_space_ids)

  asg   = cloudfoundry_asg.asg.id
  space = each.value
  type  = "running"
}

# Bind ASG to spaces for staging applications
resource "cloudfoundry_asg_space_binding" "staging" {
  for_each = toset(var.staging_space_ids)

  asg   = cloudfoundry_asg.asg.id
  space = each.value
  type  = "staging"
}

output "asg_id" {
  value = cloudfoundry_asg.asg.id
}

output "asg_name" {
  value = cloudfoundry_asg.asg.name
}
