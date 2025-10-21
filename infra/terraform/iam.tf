resource "aws_iam_role" "ec2_role" {
  name = "${var.app_name}-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" } }]
  })
  tags = { Name = "${var.app_name}-ec2-role" }
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "ssm_managed" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_policy" "app_s3_policy" {
  name        = "${var.app_name}-s3-policy"
  description = "S3 access for ${var.app_name}"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Sid="S3ArtifactsRead", Effect="Allow", Action=["s3:GetObject","s3:ListBucket"], Resource=[aws_s3_bucket.artifacts.arn,"${aws_s3_bucket.artifacts.arn}/*"] },
      { Sid="S3BackupWrite",   Effect="Allow", Action=["s3:PutObject","s3:GetObject","s3:ListBucket"], Resource=[aws_s3_bucket.backup.arn,"${aws_s3_bucket.backup.arn}/*"] },
      { Sid="EC2Describe",     Effect="Allow", Action=["ec2:DescribeInstances","ec2:DescribeTags"], Resource="*" }
    ]
  })
  tags = { Name = "${var.app_name}-s3-policy" }
}

resource "aws_iam_role_policy_attachment" "app_s3_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.app_s3_policy.arn
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.app_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
  tags = { Name = "${var.app_name}-ec2-profile" }
}
