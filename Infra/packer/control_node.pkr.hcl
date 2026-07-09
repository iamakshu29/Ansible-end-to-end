packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "ami_prefix" {
  type    = string
  default = "ansible_controller_ami"
}


source "amazon-ebs" "ubuntu" {
  ami_name      = "${var.ami_prefix}"
  instance_type = "t3.medium"
  region        = "us-east-1"
  source_ami_filter {
    most_recent = true

    owners = ["099720109477"] # Canonical

    filter {
      name   = "name"
      values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
    }

    filter {
      name   = "virtualization-type"
      values = ["hvm"]
    }
  }
  ssh_username = "ubuntu"
}

build {
  name = "configure-ansible"
  sources = [
    "source.amazon-ebs.ubuntu"
  ]

  provisioner "shell" {
    script = "install_tools.sh"
  }

  provisioner "file" {
    source      = "plugins.txt"
    destination = "/tmp/plugins.txt"
  }

  provisioner "shell" {
    inline = [
      "sudo jenkins-plugin-cli --plugin-file /tmp/plugins.txt",
      "sudo systemctl restart jenkins"
    ]
  }

  provisioner "file" {
  source      = "jenkins.yaml"
  destination = "/tmp/jenkins.yaml"
  }

  provisioner "shell" {
    inline = [
      "sudo mv /tmp/jenkins.yaml /var/lib/jenkins/jenkins.yaml",
      "sudo chown jenkins:jenkins /var/lib/jenkins/jenkins.yaml",
      "sudo mkdir -p /etc/systemd/system/jenkins.service.d",
      "printf '[Service]\nEnvironment=\"CASC_JENKINS_CONFIG=/var/lib/jenkins/jenkins.yaml\"\n' | sudo tee /etc/systemd/system/jenkins.service.d/override.conf",
      "sudo systemctl daemon-reload",
      "sudo systemctl restart jenkins"
    ]
  }
}
