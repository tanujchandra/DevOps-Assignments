region = "ap-south-1"
env    = "dev"

# true = plan without AWS credentials. Set false for a real apply.
mock_credentials = true

# ---- Network ----
azs                  = ["ap-south-1a", "ap-south-1b"]
vpc_cidr             = "10.10.0.0/16"
public_subnet_cidrs  = ["10.10.1.0/24", "10.10.2.0/24"]
private_subnet_cidrs = ["10.10.11.0/24", "10.10.12.0/24"]
enable_nat_gateway   = true
single_nat_gateway   = true # one shared NAT: cheaper for dev

# ---- ECS (small) ----
container_image         = "nginx:stable"
container_port          = 80
ecs_cpu                 = 256
ecs_memory              = 512
ecs_desired_count       = 1
log_retention_days      = 7
alb_deletion_protection = false

# ---- RDS (small, short backups, deletable) ----
db_name                    = "hotel"
db_username                = "app"
db_instance_class          = "db.t4g.micro"
db_allocated_storage       = 20
db_max_allocated_storage   = 0
db_multi_az                = false
db_backup_retention_period = 1
db_deletion_protection     = false
db_skip_final_snapshot     = true
