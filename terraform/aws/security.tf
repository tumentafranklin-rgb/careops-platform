resource "aws_security_group" "careops" {
  name_prefix = "careops-app-"
  description = "Network access for the CareOps learning application"
  vpc_id      = data.aws_vpc.default.id

  tags = {
    Name        = "careops-app"
    Project     = "careops-platform"
    Environment = "learning"
    ManagedBy   = "terraform"
  }
}

resource "aws_vpc_security_group_ingress_rule" "careops_app" {
  security_group_id = aws_security_group.careops.id
  description       = "Application access from my current public IP"
  cidr_ipv4         = "73.30.71.184/32"
  ip_protocol       = "tcp"
  from_port         = 5000
  to_port           = 5000
}

resource "aws_vpc_security_group_egress_rule" "careops_outbound" {
  security_group_id = aws_security_group.careops.id
  description       = "Outbound access for software downloads and AWS services"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}