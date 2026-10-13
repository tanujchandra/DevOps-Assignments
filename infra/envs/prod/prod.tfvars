region = "ap-south-1"
env    = "prod"

# true = plan without AWS credentials. Set false for a real apply.
mock_credentials = true

# ---- Network ----
azs                  = ["ap-south-1a", "ap-south-1b"]
vpc_cidr             = "10.20.0.0/16"
public_subnet_cidrs  = ["10.20.1.0/24", "10.20.2.0/24"]
private_subnet_cidrs = ["10.20.11.0/24", "10.20.12.0/24"]
enable_nat_gateway   = true
single_nat_gateway   = false # one NAT per AZ: survives an AZ failure

# ---- ECS (larger, 2 tasks) ----
container_image         = "nginx:stable"
container_port          = 80
ecs_cpu                 = 1024
ecs_memory              = 2048
ecs_desired_count       = 2
log_retention_days      = 90
alb_deletion_protection = true
# certificate_arn = "arn:aws:acm:ap-south-1:<account-id>:certificate/<id>"  # enables HTTPS

# ---- RDS (larger, long backups, protected) ----
db_name                    = "hotel"
db_username                = "app"
db_instance_class          = "db.m6g.large"
db_allocated_storage       = 100
db_max_allocated_storage   = 500
db_multi_az                = true
db_backup_retention_period = 14
db_deletion_protection     = true
db_skip_final_snapshot     = false
