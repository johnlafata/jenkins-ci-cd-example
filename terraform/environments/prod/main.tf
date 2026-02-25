# Production Environment — Cloud Foundry Infrastructure
#
# Mirrors dev topology:
#   - prod org
#   - app1-space, app2-space (default ASG, egress restricted)
#   - app3-space (isolation segment, custom ASG with port 1433)

terraform {
  required_version = ">= 1.5"

  required_providers {
    cloudfoundry = {
      source  = "cloudfoundry/cloudfoundry"
      version = "~> 0.53"
    }
  }

  # TODO: Configure remote backend
  # backend "s3" {
  #   bucket = "terraform-state"
  #   key    = "prod/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

provider "cloudfoundry" {
  api_url  = var.cf_api_endpoint
  user     = var.cf_username
  password = var.cf_password
}

# ---------- Variables ----------

variable "cf_api_endpoint" {
  description = "Cloud Foundry API endpoint"
  type        = string
}

variable "cf_username" {
  description = "Cloud Foundry admin username"
  type        = string
  sensitive   = true
}

variable "cf_password" {
  description = "Cloud Foundry admin password"
  type        = string
  sensitive   = true
}

variable "isolation_segment_id" {
  description = "ID of the pre-existing isolation segment for App 3"
  type        = string
}

variable "sql_server_cidr" {
  description = "CIDR block of the authenticated SQL server (for App 3 ASG)"
  type        = string
}

variable "developers" {
  description = "List of developer usernames"
  type        = list(string)
  default     = []
}

variable "managers" {
  description = "List of space manager usernames"
  type        = list(string)
  default     = []
}

# ---------- Org ----------

module "prod_org" {
  source = "../../modules/cf-org"

  org_name = "prod"
  org_quota = {
    name                     = "prod-quota"
    total_memory             = 40960  # 40 GB (production headroom)
    instance_memory          = 4096
    total_routes             = 200
    total_services           = 100
    total_app_instances      = 60
    allow_paid_service_plans = true
  }
}

# ---------- Spaces (Apps 1 & 2 — Default ASG) ----------

module "app1_space" {
  source = "../../modules/cf-space"

  space_name = "app1-space"
  org_id     = module.prod_org.org_id
  developers = var.developers
  managers   = var.managers

  space_quota = {
    name            = "app1-space-quota-prod"
    total_memory    = 8192  # 8 GB (production headroom for SQL + apps)
    instance_memory = 4096
    total_routes    = 20
    total_services  = 10
  }
}

module "app2_space" {
  source = "../../modules/cf-space"

  space_name = "app2-space"
  org_id     = module.prod_org.org_id
  developers = var.developers
  managers   = var.managers
}

# ---------- Space (App 3 — Isolation Segment) ----------

module "app3_space" {
  source = "../../modules/cf-space"

  space_name           = "app3-space"
  org_id               = module.prod_org.org_id
  isolation_segment_id = var.isolation_segment_id
  developers           = var.developers
  managers             = var.managers
}

# ---------- Application Security Groups ----------

module "app3_sql_asg" {
  source = "../../modules/cf-asg"

  asg_name = "app3-sql-access-prod"
  rules = [
    {
      protocol    = "tcp"
      destination = var.sql_server_cidr
      ports       = "1433"
      description = "Allow egress to authenticated SQL server for App 3"
    }
  ]

  running_space_ids = [module.app3_space.space_id]
  staging_space_ids = [module.app3_space.space_id]
}

# ---------- Outputs ----------

output "org_id" {
  value = module.prod_org.org_id
}

output "app1_space_id" {
  value = module.app1_space.space_id
}

output "app2_space_id" {
  value = module.app2_space.space_id
}

output "app3_space_id" {
  value = module.app3_space.space_id
}
