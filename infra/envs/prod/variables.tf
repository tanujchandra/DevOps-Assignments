variable "region" {
  type = string
}

variable "env" {
  type = string
}

variable "mock_credentials" {
  description = "true = plan-only without AWS credentials"
  type        = bool
  default     = true
}

# ---- Network ----
variable "azs" {
  type = list(string)
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "enable_nat_gateway" {
  type = bool
}

variable "single_nat_gateway" {
  type = bool
}

# ---- ECS ----
variable "container_image" {
  type = string
}

variable "container_port" {
  type = number
}

variable "ecs_cpu" {
  type = number
}

variable "ecs_memory" {
  type = number
}

variable "ecs_desired_count" {
  type = number
}

variable "log_retention_days" {
  type = number
}

variable "alb_deletion_protection" {
  type = bool
}

variable "certificate_arn" {
  type    = string
  default = null
}

# ---- RDS ----
variable "db_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_instance_class" {
  type = string
}

variable "db_allocated_storage" {
  type = number
}

variable "db_max_allocated_storage" {
  type = number
}

variable "db_multi_az" {
  type = bool
}

variable "db_backup_retention_period" {
  type = number
}

variable "db_deletion_protection" {
  type = bool
}

variable "db_skip_final_snapshot" {
  type = bool
}
