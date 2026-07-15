#!/bin/bash

mkdir -p /home/ubuntu/.ssh
mkdir -p /home/ubuntu/git_repo

aws ssm get-parameter \
    --name "/ansible/managed_node/key" \
    --with-decryption \
    --query "Parameter.Value" \
    --output text > /home/ubuntu/.ssh/ansible_managed_node.pem

chmod 400 /home/ubuntu/.ssh/ansible_managed_node.pem

chown ubuntu:ubuntu /home/ubuntu/.ssh/ansible_managed_node.pem

cd /home/ubuntu/git_repo
git clone https://github.com/iamakshu29/Ansible-end-to-end
sudo chown -R ubuntu:ubuntu ~/git_repo/Ansible-end-to-end