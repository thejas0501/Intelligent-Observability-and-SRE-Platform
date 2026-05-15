output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "ec2_public_ip" {
  description = "Flask app server public IP"
  value       = module.ec2.public_ip
}

output "ec2_public_dns" {
  description = "Flask app server public DNS"
  value       = module.ec2.public_dns
}

output "rds_endpoint" {
  description = "RDS MySQL endpoint"
  value       = module.rds.db_endpoint
  sensitive   = true
}
