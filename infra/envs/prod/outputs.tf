output "alb_dns_name" {
  description = "Public entry point (Internet -> ALB)"
  value       = module.ecs.alb_dns_name
}

output "db_endpoint" {
  description = "Private RDS endpoint (reachable only from ECS)"
  value       = module.rds.endpoint
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}
