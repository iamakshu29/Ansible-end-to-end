resource "aws_security_group" "ansible_sg" {
  for_each    = var.security_group
  name        = "${each.key}-sg"
  description = "Allow SSH inbound traffic and all outbound traffic"
  vpc_id      = data.aws_vpc.default.id

  tags = {
    Name = each.key
  }
}


resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4_ansible_server_rule" {
  for_each = { for rule in local.ingress_rules : "${rule.sg_name}_${rule.idx}" => rule }

  security_group_id            = aws_security_group.ansible_sg[each.value.sg_name].id
  cidr_ipv4                    = each.value.cidr_ipv4
  referenced_security_group_id = each.value.sg_name == "managed_node" ? aws_security_group.ansible_sg["controller_node"].id : null
  from_port                    = each.value.from_port
  ip_protocol                  = each.value.ip_protocol
  to_port                      = each.value.to_port
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4_ansible_server_rule" {
  for_each = var.security_group

  security_group_id = aws_security_group.ansible_sg[each.key].id
  cidr_ipv4         = each.value.eggress.cidr_ipv4
  ip_protocol       = each.value.eggress.ip_protocol
}
