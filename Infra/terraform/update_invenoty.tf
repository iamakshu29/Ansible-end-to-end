resource "local_file" "inventory" {
  content = templatefile("${path.module}/inventory.yml.tpl", {
    managed_one_ip = aws_instance.ansible["managed_one"].private_ip
    managed_two_ip = aws_instance.ansible["managed_two"].private_ip
  })
  filename = "${path.module}/../../01_Variables_Facts_Jinja2/inventory/inventory.yml"
}