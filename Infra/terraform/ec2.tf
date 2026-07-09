resource "aws_key_pair" "ansible_key" {
  for_each   = var.ssh_key
  key_name   = each.key
  public_key = file("${path.module}/${each.value.key_path}")
}

resource "aws_instance" "ansible" {
  for_each = var.instance

  ami                    = each.key == "ansible_controller" ? data.aws_ami.ansible_controller.id : data.aws_ami.ubuntu.id
  instance_type          = each.value.instance_type
  key_name               = aws_key_pair.ansible_key[local.instance_key_map[each.key]].key_name
  subnet_id              = data.aws_subnet.default[each.value.availability_zone].id
  vpc_security_group_ids = [aws_security_group.ansible_sg[local.instance_sg_map[each.key]].id]
  iam_instance_profile   = each.key == "ansible_controller" ? aws_iam_instance_profile.jenkins.name : null
}

resource "aws_ebs_volume" "ansible_ebs" {
  for_each = var.instance

  size              = each.value.size
  encrypted         = true
  availability_zone = each.value.availability_zone
}

resource "aws_volume_attachment" "strata_vol_att" {
  for_each = var.instance

  device_name = "/dev/sdh" # Linux device mounting path
  volume_id   = aws_ebs_volume.ansible_ebs[each.key].id
  instance_id = aws_instance.ansible[each.key].id
}
