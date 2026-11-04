resource "aws_iam_role" "careops_ec2" {
  name = "careops-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "careops_ssm" {
  role       = aws_iam_role.careops_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "careops_ecr_pull" {
  name = "careops-ecr-pull"
  role = aws_iam_role.careops_ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = aws_ecr_repository.careops.arn
      }
    ]
  })
}

resource "aws_iam_instance_profile" "careops" {
  name = "careops-ec2-profile"
  role = aws_iam_role.careops_ec2.name
}