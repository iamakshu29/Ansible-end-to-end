# The flow is:
# IAM Role — identity that your EC2 assumes
# Trust policy — defines who can assume the role (EC2 service in this case)
# IAM Policy, which contains rules/permissions
# Policy attachment — attaches the policy to the role
# Instance profile — wraps the role so EC2 can use it
# policy_document -> policy -> role -> policy_attachment -> instance_profile -> attach to EC2

data "aws_iam_policy_document" "ansible_controller_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# Allows the controller EC2 to call EC2 Describe APIs needed by the AWS dynamic inventory plugin
resource "aws_iam_role" "ansible_controller" {
  name               = "AnsibleControllerRole"
  assume_role_policy = data.aws_iam_policy_document.ansible_controller_assume_role.json
}

resource "aws_iam_policy" "ansible_controller" {
  name        = "AnsibleControllerPolicy"
  description = "EC2 dynamic inventory read + SSM parameter retrieval for the controller node"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeTags",
          "ec2:DescribeRegions"
        ]

        Resource = "*"
      },
      {
        Effect = "Allow"

        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]

        Resource = "arn:aws:ssm:*:*:parameter/ansible/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ansible_controller" {
  role       = aws_iam_role.ansible_controller.name
  policy_arn = aws_iam_policy.ansible_controller.arn
}

resource "aws_iam_instance_profile" "ansible_controller" {
  name = "AnsibleControllerInstanceProfile"
  role = aws_iam_role.ansible_controller.name
}
