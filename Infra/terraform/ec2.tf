resource "aws_key_pair" "ansible_key" {
  for_each   = var.ssh_key
  key_name   = each.key
  public_key = file("${path.module}/${each.value.key_path}")
}

resource "aws_instance" "ansible" {
  for_each = var.instance

  ami                    = each.key == "ansible_controller" ? var.controller_ami_id : data.aws_ami.ubuntu.id
  instance_type          = each.value.instance_type
  key_name               = aws_key_pair.ansible_key[local.instance_key_map[each.key]].key_name
  subnet_id              = data.aws_subnet.default[each.value.availability_zone].id
  vpc_security_group_ids = [aws_security_group.ansible_sg[local.instance_sg_map[each.key]].id]
  iam_instance_profile   = each.key == "ansible_controller" ? aws_iam_instance_profile.jenkins.name : null

  root_block_device {
    volume_size = each.value.size
    encrypted   = true
  }
}
