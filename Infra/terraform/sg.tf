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
  for_each = var.security_group

  security_group_id            = aws_security_group.ansible_sg[each.key].id
  cidr_ipv4                    = each.key == "controller_node" ? each.value.ingress.cidr_ipv4 : null
  referenced_security_group_id = each.key == "managed_node" ? aws_security_group.ansible_sg["controller_node"].id : null
  from_port                    = each.value.ingress.from_port
  ip_protocol                  = each.value.ingress.ip_protocol
  to_port                      = each.value.ingress.to_port
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4_ansible_server_rule" {
  for_each = var.security_group

  security_group_id = aws_security_group.ansible_sg[each.key].id
  cidr_ipv4         = each.value.eggress.cidr_ipv4
  ip_protocol       = each.value.eggress.ip_protocol
}
