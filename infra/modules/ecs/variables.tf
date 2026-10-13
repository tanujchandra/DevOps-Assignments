variable "name" {
  type = string
}

variable "region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "alb_security_group_id" {
  type = string
}

variable "ecs_security_group_id" {
  type = string
}

variable "container_image" {
  description = "Any simple image, e.g. nginx:stable"
  type        = string
  default     = "nginx:stable"
}

variable "container_port" {
  type    = number
  default = 80
}

variable "health_check_path" {
  type    = string
  default = "/"
}

variable "cpu" {
  description = "Fargate task CPU units (256, 512, 1024, ...)"
  type        = number
}

variable "memory" {
  description = "Fargate task memory in MiB"
  type        = number
}

variable "desired_count" {
  type = number
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "alb_deletion_protection" {
  type    = bool
  default = false
}

variable "certificate_arn" {
  description = "ACM certificate ARN. If set, HTTPS listener is created and HTTP redirects to HTTPS."
  type        = string
  default     = null
}

variable "db_host" {
  type = string
}

variable "db_port" {
  type = number
}

variable "db_name" {
  type = string
}

variable "db_secret_arn" {
  description = "Secrets Manager secret with username and password keys"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
