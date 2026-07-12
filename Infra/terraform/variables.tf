variable "ssh_key" {
  type = map(any)
}

variable "controller_ami_id" {
  description = "AMI ID for the Ansible controller node"
  type        = string
}

variable "instance" {
  type = map(any)
}

variable "security_group" {
  type = map(any)
}

variable "ssm_parameter" {
  type = map(any)
}