output "instance_id" {
  value       = aws_instance.app.id
  description = "ID of the EC2 instance"
}

output "instance_public_ip" {
  value       = aws_instance.app.public_ip
  description = "Public IP of the EC2 instance"
}

output "app_url" {
  value       = "http://${aws_instance.app.public_ip}"
  description = "Application URL"
}

output "artifacts_bucket" {
  value       = aws_s3_bucket.artifacts.id
  description = "S3 bucket for artifacts"
}

output "backup_bucket" {
  value       = aws_s3_bucket.backup.id
  description = "S3 bucket for backups"
}

output "cloudwatch_dashboard_url" {
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.app.dashboard_name}"
  description = "CloudWatch Dashboard URL"
}

output "ssh_command" {
  value       = "ssh -i ~/.ssh/ec2-key.pem ubuntu@${aws_instance.app.public_ip}"
  description = "SSH command to connect to instance"
}
