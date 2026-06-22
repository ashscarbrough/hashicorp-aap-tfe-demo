#!/bin/bash
set -euo pipefail
exec > >(tee /var/log/user-data.log | logger -t user-data) 2>&1

echo "=== User data start ==="

# Set a stable hostname for AAP inventory identification
hostnamectl set-hostname liberty-mutable-demo

# Wait for network to be fully ready before starting SSM agent
# SSM needs to reach the service endpoints and will fail silently
# if started before networking is available
sleep 10

# Enable first so it persists across reboots
systemctl enable amazon-ssm-agent

# Start with retries -- SSM endpoint may not be reachable immediately
for i in {1..5}; do
  if systemctl start amazon-ssm-agent; then
    echo "SSM agent started successfully on attempt $i"
    break
  fi
  echo "SSM agent start attempt $i failed, retrying in 10s..."
  sleep 10
done

# Verify agent is running
systemctl status amazon-ssm-agent --no-pager

# Signal that user_data has completed
touch /tmp/userdata-complete

echo "==== User data complete ===="