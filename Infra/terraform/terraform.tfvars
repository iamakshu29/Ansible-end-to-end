ssh_key = {
  ansible_controller = {
    key_path = "ansible_controller.pub"
  }
  ansible_managed_node = {
    key_path = "ansible_managed_node.pub"
  }
}

instance = {
  ansible_controller = {
    size              = 12
    availability_zone = "us-east-1a"
    instance_type     = "t3.medium"
  }
  managed_one = {
    size              = 8
    availability_zone = "us-east-1b"
    instance_type     = "t3.micro"
  }
  managed_two = {
    size              = 8
    availability_zone = "us-east-1c"
    instance_type     = "t3.micro"
  }
}

security_group = {
  controller_node = {
    ingress = [
      {
        cidr_ipv4   = "0.0.0.0/0"
        from_port   = 22
        ip_protocol = "tcp"
        to_port     = 22
      },
      {
        cidr_ipv4   = "0.0.0.0/0"
        from_port   = 8080
        ip_protocol = "tcp"
        to_port     = 8080
      }
    ]

    eggress = {
      cidr_ipv4   = "0.0.0.0/0"
      ip_protocol = "-1"
    }
  }

  managed_node = {
    ingress = [
      {
        from_port   = 22
        ip_protocol = "tcp"
        to_port     = 22
      }
    ]

    eggress = {
      cidr_ipv4   = "0.0.0.0/0"
      ip_protocol = "-1"
    }
  }
}

ssm_parameter = {
  name = "/ansible/managed_node/key"
  description = "It contains the private ssh key for ansible managed node"
  type = "SecureString"
}