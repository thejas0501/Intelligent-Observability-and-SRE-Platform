variable "aws_region" {
  description = "AWS region"
  default     = "ap-south-1"
}

variable "environment" {
  description = "Environment name"
  default     = "dev"
}

variable "project_name" {
  description = "Project identifier"
  default     = "intelligent-observability-sre"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  default     = "10.0.0.0/16"
}

variable "db_password" {
  description = "RDS MySQL root password"
  type        = string
  sensitive   = true
}

variable "my_ip" {
  description = "Your public IP for SSH access"
  type        = string
}

variable "alert_email" {
  description = "Email for anomaly alerts"
  type        = string
}
