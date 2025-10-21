data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_vpc" "main" {
  cidr_block = "10.42.0.0/16"
  tags = { Name = "devops-demo-vpc" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.42.1.0/24"
  map_public_ip_on_launch = true
  tags = { Name = "devops-demo-public" }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "devops-demo-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = { Name = "devops-demo-rt" }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "app" {
  name        = "devops-demo-sg"
  description = "Allow HTTP/SSH"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All out"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "devops-demo-sg" }
}

# S3 buckets (artifacts + backup)
resource "aws_s3_bucket" "artifacts" {
  bucket = "artifacts-${random_id.bucket_suffix.hex}"
  force_destroy = true
  tags = { Name = "artifacts" }
}

resource "aws_s3_bucket" "backup" {
  bucket = "backup-${random_id.bucket_suffix.hex}"
  force_destroy = true
  tags = { Name = "backup" }
}

# IAM + Instance profile in iam.tf

resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

    user_data = base64encode(templatefile("${path.module}/userdata.sh", {
    APP_NAME         = var.app_name
    AWS_REGION       = var.aws_region
    BACKUP_BUCKET    = aws_s3_bucket.backup.id
    ARTIFACTS_BUCKET = aws_s3_bucket.artifacts.id
    IMAGE_REPO       = var.docker_image_repo
    IMAGE_TAG        = var.docker_image_tag
  }))

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 10
    encrypted             = true
    delete_on_termination = true
    tags = { Name = "${var.app_name}-root-volume" }
  }

  metadata_options {
    http_tokens                 = "required"
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  # esplicito per t2.micro (crediti baseline)
  credit_specification {
    cpu_credits = "standard"
  }

  monitoring = false

  tags = {
    Name      = "${var.app_name}-instance"
    Type      = "application-server"
    Backup    = "true"
    AutoPatch = "false"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}
