provider "aws" {
  region = "us-west-2"
}

# 最新 Amazon Linux 2023 AMI を取得
data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  owners = ["137112412989"] # Amazon
}

# セキュリティグループ
resource "aws_security_group" "web_sg" {
  name        = "tokio_sg"
  description = "Security group for WordPress server"
  vpc_id      = "vpc-009484d4b9b045f5e"

  # SSH（自分のIPから）
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["118.237.255.201/32"]
    description = "Allow SSH from my IP"
  }

  # HTTP（全世界アクセス）
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP access"
  }

  # HTTPS（全世界アクセス、必要なら）
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS access"
  }

  # アウトバウンドはすべて許可
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 インスタンス
resource "aws_instance" "web_server" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  key_name               = "toshiki"
  subnet_id              = "subnet-006eca036318c8a0b"
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # EBS 暗号化 & 最適化
  root_block_device {
    encrypted = true
  }
  ebs_optimized = true

  # 詳細モニタリング
  monitoring = true

  # IMDSv2 強制
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name = "tokio_web_server"
  }
}

# Terraform backend
terraform {
  backend "s3" {
    bucket = "tokio.t-tfstate"
    key    = "wordpress/terraform.tfstate"
    region = "us-west-2"
  }
}

# 出力
output "instance_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.web_server.public_ip
}

output "security_group_id" {
  value = aws_security_group.web_sg.id
  description = "Security Group ID for SSH access"
}