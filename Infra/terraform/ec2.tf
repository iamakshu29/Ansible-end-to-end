data "aws_ami" "ubuntu" {
  most_recent = true

  owners = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ssh-keygen -t ed25519 -f ./strata-key
resource "aws_key_pair" "strata_key" {
  key_name   = "strata-server-key"
  public_key = file("${path.module}/strata-key.pub")
}

resource "aws_instance" "ansible_managed_node" {
  for_each                    = var.instance
  ami                         = try(each.ami, data.aws_ami.ubuntu.id)
  instance_type               = each.value.instance_type
  key_name                    = aws_key_pair.strata_key.key_name
  associate_public_ip_address = var.aws_bastian_instance.associate_public_ip_address
  #   vpc_security_group_ids      = [aws_security_group.strata_sg["bastion"].id]
}

resource "aws_ebs_volume" "ansible_ebs" {
  for_each          = var.instance
  size              = each.value.size
  encrypted         = true
  availability_zone = each.value.availability_zone
}

resource "aws_volume_attachment" "strata_vol_att" {
  for_each    = var.instance
  device_name = "/dev/sdh" # Linux device mounting path
  volume_id   = aws_ebs_volume.ansible_ebs[each.value.key].id
  instance_id = aws_instance.ansible_instance[each.value.key].id
}


# security group issue is there as I want 2 sg only
# 1 for controller node and 1 for all managed node
# what If in future we need to add more isntance so all managed should have same SG for that time or atleast the basic same rules

# For that we need to map managed SG with instance using LOCALS
# as sg are - cotnroller and managed
# isntnace are cotnroller, managed_one, managed_two
