# ------------------------------------------------------------------
# Traffic chain:  Internet -> ALB SG -> ECS SG -> RDS SG
# All three groups live here so the modules that use them
# (ecs, rds) never depend on each other (no circular dependency).
# ------------------------------------------------------------------

# ---------------- ALB security group ----------------
resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "ALB: accepts web traffic from the internet"
  vpc_id      = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-alb-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_from_internet" {
  for_each = toset([for p in var.alb_ingress_ports : tostring(p)])

  security_group_id = aws_security_group.alb.id
  description       = "Internet to ALB on ${each.value}"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = tonumber(each.value)
  to_port           = tonumber(each.value)
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_ecs" {
  security_group_id            = aws_security_group.alb.id
  description                  = "ALB to ECS tasks only"
  referenced_security_group_id = aws_security_group.ecs.id
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
}

# ---------------- ECS/Fargate security group ----------------
resource "aws_security_group" "ecs" {
  name        = "${var.name}-ecs-sg"
  description = "ECS tasks: accept traffic from the ALB only"
  vpc_id      = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-ecs-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb" {
  security_group_id            = aws_security_group.ecs.id
  description                  = "ALB to ECS tasks"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "ecs_to_rds" {
  security_group_id            = aws_security_group.ecs.id
  description                  = "ECS tasks to RDS"
  referenced_security_group_id = aws_security_group.rds.id
  from_port                    = var.db_port
  to_port                      = var.db_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "ecs_https_out" {
  security_group_id = aws_security_group.ecs.id
  description       = "HTTPS out via NAT (image pull, Secrets Manager, CloudWatch Logs)"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

# ---------------- RDS security group ----------------
resource "aws_security_group" "rds" {
  name        = "${var.name}-rds-sg"
  description = "RDS: accepts database traffic from ECS tasks only"
  vpc_id      = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-rds-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

# The ONLY inbound rule on the database: source = ECS security group.
# No CIDR blocks, so nothing else (not even other things in the VPC) can connect.
resource "aws_vpc_security_group_ingress_rule" "rds_from_ecs" {
  security_group_id            = aws_security_group.rds.id
  description                  = "ECS tasks to database"
  referenced_security_group_id = aws_security_group.ecs.id
  from_port                    = var.db_port
  to_port                      = var.db_port
  ip_protocol                  = "tcp"
}
