# The flow is:
# IAM Role — identity that your EC2/ECS assumes
# Trust policy — defines who can assume the role (EC2 service in this case)
# IAM Policy, which contains rules/permission
# Policy attachment — attaches your policy (read_secrets_policy) to the role role_ecs_task, ...
# Instance profile — wraps the role, so EC2 can use it
# policy_document -> policy -> role -> policy_attachment (to attach that policy to a role) -> add the role to a resource 

# NEEDS REWORK

locals {
  policies = merge([
    for role_name, policy in var.iam_policy : {
      for policy_name, policy_element in policy :
      "${role_name}-${policy_name}" => {
        role_name       = role_name # role key — used to look up aws_iam_role.strata
        policy_name     = policy_name
        policy_elements = policy_element
      }
    }
  ]...)

  #### The map merges out as

  # policies = {
  #   "role_ecs_task-s3_read_write" = {
  #     role_name = "role_ecs_task"
  #     policy_name = "s3_read_write"
  #     policy_elements = {
  #       sid    = "S3ReadWrite"
  #       effect = "Allow"
  #       actions = [
  #         "s3:GetObject",
  #         "s3:WriteObject"
  #       ]
  #       resources = ["arn:aws:s3:::my-bucket/*"]
  #     }

  #   },"role_ecs_task-read_secrets" = {}, "role_ecs_task-read_cloudwatch_logs" = {},
  #     "role_ec2_instance-read_cloudwatch_logs" = {}
  # }
}

data "aws_iam_policy_document" "policy" {
  for_each = local.policies
  statement {
    sid       = each.value.policy_elements.sid
    effect    = each.value.policy_elements.effect
    actions   = each.value.policy_elements.actions
    resources = each.value.policy_elements.resources
  }
}

# Create IAM policy, for allowing an EC2 instance, ECS task, or an application to read the secret credentials
resource "aws_iam_policy" "strata_policy" {
  for_each = local.policies
  name     = "strata-${each.value.policy_name}"
  policy   = data.aws_iam_policy_document.policy[each.key].json # need to check this
}

resource "aws_iam_role" "strata" {
  for_each = var.assume_role_policy
  name     = each.key

  assume_role_policy = jsonencode({
    Version = each.value.Version
    Statement = [
      {
        Action = each.value.Action
        Effect = each.value.Effect
        Sid    = each.value.Sid
        Principal = {
          Service = each.value.Principal_Service
        }
      },
    ]
  })

  tags = local.tags
}

# Controls who can access the secret at the secret level
resource "aws_iam_role_policy_attachment" "strata_attach_policy" {
  for_each   = local.policies
  role       = aws_iam_role.strata[each.value.role_name].name
  policy_arn = aws_iam_policy.strata_policy[each.key].arn
}