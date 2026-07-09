resource "aws_security_group" "strata_sg" {
  for_each    = var.security_group
  name        = "${each.key}-sg"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.strata.id

  tags = {
    Name = "allow_tls"
  }
}


resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4_strata_server_rule" {
  for_each = var.ingress

  security_group_id            = aws_security_group.strata_sg[each.value.sg_name].id
  referenced_security_group_id = try(each.value.rule.source_security_group, null)

  cidr_ipv4   = try(each.value.rule.cidr_ipv4, null)
  from_port   = each.value.rule.from_port
  ip_protocol = each.value.rule.ip_protocol
  to_port     = each.value.rule.to_port
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4_strata_server_rule" {
  for_each = var.eggress

  security_group_id = aws_security_group.strata_sg[each.key].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}
