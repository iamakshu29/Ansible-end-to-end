#!/bin/bash
set -e


echo "Updating apt package"
sudo apt update -y



echo "Checking for Ansible"
if command -v ansible >/dev/null 2>&1; then
    echo "Ansible Already Present"
else
    echo "Ansible not present, Installing Ansible"
    sudo apt install -y ansible
fi

echo "Ansible version"
ansible --version



echo "Checking for Git"
if command -v git >/dev/null 2>&1; then
    echo "Git Already Present"
else
    echo "Git not present, Installing Git"
    sudo apt install -y git
fi

echo "Git version"
git --version



echo "Checking for AWS CLI"
if command -v aws >/dev/null 2>&1; then
    echo "AWS CLI Already Present"
else
    echo "AWS CLI not present, Installing AWS CLI"
    sudo apt install -y awscli
fi

echo "AWS CLI version"
aws --version



echo "Checking for Terraform"
if command -v terraform >/dev/null 2>&1; then
    echo "Terraform Already Present"
else
    echo "Terraform not present, Installing Terraform"
    wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt update && sudo apt install -y terraform
fi
echo "Terraform version"
terraform version



echo "Checking for Java JDK 21"
if command -v java >/dev/null 2>&1; then
    echo "Java Already Present"
else
    echo "Java not present, Installing Java 21"
    sudo apt install -y fontconfig openjdk-21-jre
fi
echo "Java version"
java -version



echo "Checking for Jenkins"
if dpkg -s jenkins >/dev/null 2>&1; then
    echo "Jenkins Already Present"
else
    sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
    echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc]" https://pkg.jenkins.io/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
    sudo apt update
    sudo apt install -y jenkins
    sudo systemctl start jenkins
    sudo systemctl enable jenkins
fi
echo "Jenkins version"
dpkg -s jenkins | grep Version