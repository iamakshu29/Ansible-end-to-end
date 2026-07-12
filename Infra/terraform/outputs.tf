output "controller_public_ip" {
  description = "Public IP of the Ansible controller. Use this to SSH in: ssh -i ansible_controller.pem ubuntu@<ip>"
  value       = aws_instance.ansible["ansible_controller"].public_ip
}

output "managed_node_private_ips" {
  description = "Private IPs of managed nodes (for reference — dynamic inventory discovers these automatically)"
  value = {
    for name, instance in aws_instance.ansible : name => instance.private_ip
    if name != "ansible_controller"
  }
}

output "instance_ids" {
  description = "EC2 instance IDs for all nodes"
  value = {
    for name, instance in aws_instance.ansible : name => instance.id
  }
}