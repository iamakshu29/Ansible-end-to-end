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
}
