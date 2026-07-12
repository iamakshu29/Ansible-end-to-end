

## 4. Dynamic Inventory Config (missing file on controller)

The `aws_ec2.yml` plugin config needs to exist on the controller.
Either bake it into the AMI or write it via `user_data`.

**File: `/etc/ansible/aws_ec2.yml`**
```yaml
plugin: amazon.aws.aws_ec2
regions:
  - us-east-1
filters:
  tag:Role: worker
  tag:Environment: lab
  instance-state-name: running
keyed_groups:
  - key: tags.Role
    prefix: role
hostnames:
  - private-ip-address
compose:
  ansible_host: private_ip_address
```

