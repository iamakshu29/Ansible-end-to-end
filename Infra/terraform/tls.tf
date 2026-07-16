resource "tls_private_key" "ansible_managed_node" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
