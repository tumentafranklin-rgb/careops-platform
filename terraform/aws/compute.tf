data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_instance" "careops" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = data.aws_subnet.careops.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.careops.id]
  iam_instance_profile        = aws_iam_instance_profile.careops.name

  user_data = templatefile("${path.module}/user-data.sh.tftpl", {
    repository_url = aws_ecr_repository.careops.repository_url
  })

  user_data_replace_on_change = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    encrypted             = true
    delete_on_termination = true
  }

  credit_specification {
    cpu_credits = "standard"
  }

  tags = {
    Name        = "careops-app"
    Project     = "careops-platform"
    Environment = "learning"
    ManagedBy   = "terraform"
  }

  depends_on = [
    aws_iam_role_policy_attachment.careops_ssm,
    aws_iam_role_policy.careops_ecr_pull,
    aws_vpc_security_group_egress_rule.careops_outbound,
    aws_vpc_security_group_ingress_rule.careops_app
  ]
}

output "instance_id" {
  value = aws_instance.careops.id
}

output "application_url" {
  value = "http://${aws_instance.careops.public_ip}:5000"
}