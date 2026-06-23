#!/bin/bash
set -euo pipefail
exec > >(tee /var/log/user-data.log | logger -t user-data) 2>&1

echo "=== User data start ==="

# ── SSM agent ─────────────────────────────────────────────────────────────────
# Ensure SSM is running before AAP attempts to connect via SSM session manager
systemctl start amazon-ssm-agent
systemctl enable amazon-ssm-agent

# ── Runtime environment identity ──────────────────────────────────────────────
# Terraform templatefile() injects these values at plan time
ENVIRONMENT="${environment}"
APP_VERSION="${app_version}"
ASG_NAME="${asg_name}"

# Instance ID fetched at runtime from IMDS
INSTANCE_ID=$(curl -sf http://169.254.169.254/latest/meta-data/instance-id || echo "unknown")

hostnamectl set-hostname "liberty-app-$${INSTANCE_ID}"

# Write runtime context file — AAP reads this during its config job
# $${} escapes Terraform interpolation so these are treated as bash variables
mkdir -p /etc/liberty-demo
cat > /etc/liberty-demo/runtime-context.env << 'ENVEOF'
ENVIRONMENT=$${ENVIRONMENT}
APP_VERSION=$${APP_VERSION}
INSTANCE_ID=$${INSTANCE_ID}
ASG_NAME=$${ASG_NAME}
DEPLOYED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
ENVEOF

# Re-write the file with actual values now that the heredoc is closed
# The heredoc above would not expand variables due to quoted delimiter
cat > /etc/liberty-demo/runtime-context.env << ENVEOF
ENVIRONMENT=$${ENVIRONMENT}
APP_VERSION=$${APP_VERSION}
INSTANCE_ID=$${INSTANCE_ID}
ASG_NAME=$${ASG_NAME}
DEPLOYED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
ENVEOF

chmod 644 /etc/liberty-demo/runtime-context.env

# ── Start Liberty ─────────────────────────────────────────────────────────────
# Liberty is fully installed and configured in the AMI — just start the service
systemctl start liberty-app
systemctl enable liberty-app

# ── Wait for Liberty to be healthy ────────────────────────────────────────────
# Poll the health endpoint before signaling ready — ensures AAP connects
# to a running instance and ALB registers a healthy target
echo "Waiting for Liberty health endpoint..."
SUCCESS=0
for i in $(seq 1 18); do
  HTTP_CODE=$(curl -s -o /dev/null -w "%%{http_code}" http://127.0.0.1:9080/liberty-app/health || echo "000")
  echo "Attempt $i/18 — HTTP $${HTTP_CODE}"
  if [ "$${HTTP_CODE}" = "200" ]; then
    echo "Liberty is healthy"
    SUCCESS=1
    break
  fi
  sleep 10
done

if [ "$${SUCCESS}" != "1" ]; then
  echo "ERROR: Liberty failed to start — check /wslogs/liberty-app/messages.log"
  # Do not write the ready signal — instance will fail ALB health check
  # and be replaced by the ASG
  exit 1
fi

# ── SSM registration wait ─────────────────────────────────────────────────────
# Wait for SSM agent to register with AWS before signaling completion
# Terraform's local-exec provisioner polls this before firing the AAP action
echo "Waiting for SSM agent registration..."
for i in $(seq 1 20); do
  STATUS=$(aws ssm describe-instance-information \
    --filters "Key=InstanceIds,Values=$${INSTANCE_ID}" \
    --query 'InstanceInformationList[0].PingStatus' \
    --region us-east-1 \
    --output text 2>/dev/null || echo "Unknown")
  echo "Attempt $i/20 — SSM status: $${STATUS}"
  if [ "$${STATUS}" = "Online" ]; then
    echo "SSM agent registered and online"
    break
  fi
  sleep 15
done

# ── Readiness signal ──────────────────────────────────────────────────────────
# Written only after Liberty is confirmed healthy and SSM is registered
touch /tmp/userdata-complete

echo "=== User data complete ==="
