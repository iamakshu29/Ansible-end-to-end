resource "aws_ssm_parameter" "store_managed_node_key" {
  name        = var.ssm_parameter.name
  description = var.ssm_parameter.description
  type        = var.ssm_parameter.type
  value       = tls_private_key.ansible_managed_node.private_key_pem
}
