variable "ssh_key" {
  type = map(any)
}

variable "controller_ami_name" {
  default = "ansible_controller_ami"
}

variable "instance" {
  type = map(any)
}

variable "security_group" {
  type = map(any)
}

