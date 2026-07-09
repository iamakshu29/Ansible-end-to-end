security_group = {
  controller_sg = {
    ingress = {
        cidr_ipv4 =
        from_port =
        ip_protocol = 
        to_port = 
    }
    eggress = {
        cidr_ipv4 =
        ip_protocol= 
    }
  }

  managed_sg = {
    ingress = {
        cidr_ipv4 =
        from_port =
        ip_protocol = 
        to_port = 
    }
    eggress = {
        cidr_ipv4 =
        ip_protocol = 
    }
  }
}

instance = {
    ansible_controller = {
        size = 12
        availability_zone = "us-east-1a"
        instance_type          = "t3.medium"
        ami = "ansible_control_node"
    }
    managed_one = {
        size = 8
        availability_zone = "us-east-1b"
        instance_type          = "t3.micro"
    }
    managed_two = {
        size = 8
        availability_zone = "us-east-1c"
        instance_type          = "t3.micro"
    }
    
}