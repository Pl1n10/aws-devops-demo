variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "demo"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "devops-api"
}

variable "alert_email" {
  description = "Email for CloudWatch alerts"
  type        = string
  default     = "alerts@example.com"
}

variable "docker_image_repo" {
  description = "Docker image repository"
  type        = string
  default     = "ghcr.io/pl1n10/devops-api"
}

variable "docker_image_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest"
}

variable "log_retention_days" {
  description = "Days to retain CloudWatch logs"
  type        = number
  default     = 7
}

variable "backup_retention_days" {
  description = "Days to retain backups before transition"
  type        = number
  default     = 30
}
