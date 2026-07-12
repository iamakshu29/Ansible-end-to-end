#!/bin/bash

mkdir -p /home/ubuntu/.ssh

aws ssm get-parameter \
    --name "/ansible/managed_node/key" \
    --with-decryption \
    --query "Parameter.Value" \
    --output text > /home/ubuntu/.ssh/ansible_managed_node.pem

chmod 400 /home/ubuntu/.ssh/ansible_managed_node.pem

chown ubuntu:ubuntu /home/ubuntu/.ssh/ansible_managed_node.pem
