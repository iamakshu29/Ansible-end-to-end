# The flow is:
# IAM Role — identity that your EC2/ECS assumes
# Trust policy — defines who can assume the role (EC2 service in this case)
# IAM Policy, which contains rules/permission
# Policy attachment — attaches your policy (read_secrets_policy) to the role role_ecs_task, ...
# Instance profile — wraps the role, so EC2 can use it
# policy_document -> policy -> role -> policy_attachment (to attach that policy to a role) -> add the role to a resource 

data "aws_iam_policy_document" "jenkins_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}


# Create IAM policy, for allowing an EC2 instance, ECS task, or an application to read the secret credentials
resource "aws_iam_role" "jenkins" {
  name               = "JenkinsEC2Role"
  assume_role_policy = data.aws_iam_policy_document.jenkins_assume_role.json
}

resource "aws_iam_policy" "terraform" {
  name = "TerraformProvisioningPolicy"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "ec2:*",
          "elasticloadbalancing:*",
          "autoscaling:*",
          "iam:PassRole",
          "iam:GetRole",
          "iam:ListInstanceProfiles",
          "iam:GetInstanceProfile",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "s3:*"
        ]

        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "terraform" {
  role       = aws_iam_role.jenkins.name
  policy_arn = aws_iam_policy.terraform.arn
}

resource "aws_iam_instance_profile" "jenkins" {
  name = "JenkinsInstanceProfile"
  role = aws_iam_role.jenkins.name
}
