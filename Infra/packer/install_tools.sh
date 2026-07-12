#!/bin/bash

###############################################################################
# Script Name : install_tools.sh
# Description : Install tools required on the Ansible controller node (Ansible, Git, AWS CLI)
# Version     : 1.0.0
# Author      : Akshat Verma
# Created     : 2026-07-10
# Last Updated: 2026-07-10
# License     : MIT
# Usage       : 
# Requirements: 
###############################################################################

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
