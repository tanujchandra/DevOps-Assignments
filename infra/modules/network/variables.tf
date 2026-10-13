variable "name" {
  description = "Name prefix for all resources, e.g. hotel-dev"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
}

variable "azs" {
  description = "Availability zones to spread subnets across"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "One CIDR per AZ for public subnets (ALB, NAT)"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "One CIDR per AZ for private subnets (ECS tasks, RDS)"
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Create NAT gateway(s) so private subnets can reach the internet (image pulls, Secrets Manager, logs)"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "true = one shared NAT (cheaper, for dev); false = one NAT per AZ (highly available, for prod)"
  type        = bool
  default     = true
}

variable "container_port" {
  description = "Port the application container listens on"
  type        = number
  default     = 80
}

variable "db_port" {
  description = "Database port (5432 for PostgreSQL, 3306 for MySQL)"
  type        = number
  default     = 5432
}

variable "alb_ingress_ports" {
  description = "Ports the ALB accepts from the internet"
  type        = list(number)
  default     = [80, 443]
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
