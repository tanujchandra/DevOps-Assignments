locals {
  name = "hotel-${var.env}"

  tags = {
    Project     = "hotel-app"
    Environment = var.env
    ManagedBy   = "terraform"
  }
}

module "network" {
  source = "../../modules/network"

  name                 = local.name
  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway
  container_port       = var.container_port
  db_port              = 5432
  tags                 = local.tags
}

module "rds" {
  source = "../../modules/rds"

  name                    = local.name
  private_subnet_ids      = module.network.private_subnet_ids
  security_group_id       = module.network.rds_security_group_id
  db_name                 = var.db_name
  db_username             = var.db_username
  instance_class          = var.db_instance_class
  allocated_storage       = var.db_allocated_storage
  max_allocated_storage   = var.db_max_allocated_storage
  multi_az                = var.db_multi_az
  backup_retention_period = var.db_backup_retention_period
  deletion_protection     = var.db_deletion_protection
  skip_final_snapshot     = var.db_skip_final_snapshot
  tags                    = local.tags
}

module "ecs" {
  source = "../../modules/ecs"

  name                    = local.name
  region                  = var.region
  vpc_id                  = module.network.vpc_id
  public_subnet_ids       = module.network.public_subnet_ids
  private_subnet_ids      = module.network.private_subnet_ids
  alb_security_group_id   = module.network.alb_security_group_id
  ecs_security_group_id   = module.network.ecs_security_group_id
  container_image         = var.container_image
  container_port          = var.container_port
  cpu                     = var.ecs_cpu
  memory                  = var.ecs_memory
  desired_count           = var.ecs_desired_count
  log_retention_days      = var.log_retention_days
  alb_deletion_protection = var.alb_deletion_protection
  certificate_arn         = var.certificate_arn
  db_host                 = module.rds.endpoint
  db_port                 = module.rds.port
  db_name                 = module.rds.db_name
  db_secret_arn           = module.rds.master_secret_arn
  tags                    = local.tags
}
