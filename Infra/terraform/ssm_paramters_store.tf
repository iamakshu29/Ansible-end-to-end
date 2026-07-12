resource "aws_ssm_parameter" "store_managed_node_key" {
  name  = var.ssm_parameter.name
  description = var.ssm_parameter.description
  type  = var.ssm_parameter.type
  value = file("${path.module}/ansible_managed_node.pem")
}
