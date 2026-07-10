locals {
  instance_key_map = {
    ansible_controller = "ansible_controller"
    managed_one        = "ansible_managed_node"
    managed_two        = "ansible_managed_node"
  }

  instance_sg_map = {
    ansible_controller = "controller_node"
    managed_one        = "managed_node"
    managed_two        = "managed_node"
  }

  ingress_rules = flatten([
    for sg_name, sg_config in var.security_group : [
      for idx, rule in sg_config.ingress : {
        sg_name     = sg_name
        idx         = idx
        cidr_ipv4   = lookup(rule, "cidr_ipv4", null)
        from_port   = rule.from_port
        ip_protocol = rule.ip_protocol
        to_port     = rule.to_port
      }
    ]
  ])
}
