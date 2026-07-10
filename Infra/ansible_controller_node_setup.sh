#!/bin/bash

###############################################################################
# Script Name : ansible_controller_node_setup.sh
# Description : Creates Controller Node Infra using Packer and Terraform
# Version     : 1.0.0
# Author      : Akshat Verma
# Created     : 2026-07-10
# Last Updated: 2026-07-10
# License     : MIT
# Usage       : 
# Requirements: 
###############################################################################

read -rp "What do you want to do? (apply/destroy): " ACTION

echo "Checking for Packer"
if command -v packer >/dev/null 2>&1; then
    echo "Packer already present"
    packer version
    echo ""
else
    echo "Packer not present, Install Packer First"
fi

echo "Checking for Terraform"
if command -v terraform >/dev/null 2>&1; then
    echo "Terraform already present"
    terraform version
    echo ""
else
    echo "Terraform not present, Install Terraform First"
fi

echo "Initializing Packer..."
packer init ./packer

echo "Initializing Terraform..."
terraform -chdir=./terraform init

case "$ACTION" in
    apply)
        echo "Validating Packer..."
        packer validate ./packer/ansible_controller_node.pkr.hcl

        echo "Building AMI using Packer, Store the output to manifest.json"
        packer build ./packer/ansible_controller_node.pkr.hcl

        AMI_ID=$(grep '"artifact_id"' manifest.json | tail -n 1 | cut -d'"' -f4 | cut -d':' -f2)

        if [[ -z "$AMI_ID" ]]; then
            echo "Failed to create AMI"
            exit 1
        fi

        echo "Created AMI: $AMI_ID"

        echo "Validating Terraform..."
        terraform -chdir=./terraform validate

        echo "Planning Terraform..."
        terraform -chdir=./terraform plan -var="controller_ami_id=$AMI_ID" -out=tfplan

        echo "Applying Terraform..."
        terraform -chdir=./terraform apply tfplan
    ;;

    destroy)
        echo "Destroying Terraform infrastructure..."
        terraform -chdir=./terraform destroy
    ;;

    *)
        echo "Invalid option: $ACTION"
        echo "Please enter either 'apply' or 'destroy'."
        exit 1
    ;;
esac