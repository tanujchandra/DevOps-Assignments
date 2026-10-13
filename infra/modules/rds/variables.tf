variable "name" {
  type = string
}

variable "private_subnet_ids" {
  description = "Private subnets for the DB subnet group"
  type        = list(string)
}

variable "security_group_id" {
  description = "RDS security group (allows only ECS)"
  type        = string
}

variable "engine_version" {
  type    = string
  default = "16"
}

variable "instance_class" {
  type = string
}

variable "allocated_storage" {
  type = number
}

variable "max_allocated_storage" {
  description = "Upper limit for storage autoscaling (0 disables)"
  type        = number
  default     = 0
}

variable "db_name" {
  type    = string
  default = "hotel"
}

variable "db_username" {
  type    = string
  default = "app"
}

variable "multi_az" {
  type    = bool
  default = false
}

variable "backup_retention_period" {
  description = "Days to keep automated backups"
  type        = number
}

variable "deletion_protection" {
  type = bool
}

variable "skip_final_snapshot" {
  type = bool
}

variable "tags" {
  type    = map(string)
  default = {}
}
