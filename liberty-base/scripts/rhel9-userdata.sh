#!/bin/bash
exec > >(tee /var/log/user-data.log | logger -t user-data) 2>&1

echo "=== User data start ==="

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION="us-east-1"

# Set hostname
hostnamectl set-hostname liberty-mutable-demo
echo "Hostname set to liberty-mutable-demo"

# Start SSM agent -- it's pre-installed in the AMI and enabled at build time
# but we explicitly start it here to ensure it's running before we poll
systemctl start amazon-ssm-agent
echo "SSM agent started"

# Wait for SSM agent to register with the SSM service
# This signal is consumed by Terraform's local-exec provisioner
# which polls the same status before firing the AAP action trigger
echo "Waiting for SSM agent to register with AWS..."

for i in $(seq 1 20); do
  STATUS=$(aws ssm describe-instance-information \
    --filters "Key=InstanceIds,Values=$INSTANCE_ID" \
    --query 'InstanceInformationList[0].PingStatus' \
    --region "$REGION" \
    --output text 2>/dev/null || echo "Unknown")

  echo "Attempt $i/20 -- SSM registration status: $STATUS"

  if [ "$STATUS" = "Online" ]; then
    echo "SSM agent registered and online"
    break
  fi
  sleep 15
done

touch /tmp/userdata-complete
echo "=== User data complete ==="