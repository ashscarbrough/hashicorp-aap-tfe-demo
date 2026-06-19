#!/bin/bash
set -euo pipefail
exec > >(tee /var/log/user-data.log | logger -t user-data) 2>&1

echo "=== User data start ==="

# Ensure SSM agent is running — required for AAP connectivity via SSM
# port forwarding before any inbound SSH rules exist
systemctl start amazon-ssm-agent
systemctl enable amazon-ssm-agent

# Set a stable hostname for AAP inventory identification
hostnamectl set-hostname liberty-mutable-demo

# Signal that user_data has completed — Terraform can poll this
# via SSM run command before triggering the AAP job
touch /tmp/userdata-complete

echo "=== User data complete ==="