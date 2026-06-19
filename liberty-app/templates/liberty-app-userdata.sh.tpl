#!/bin/bash
set -euo pipefail
exec > >(tee /var/log/user-data.log | logger -t user-data) 2>&1

echo "=== User data start ==="

# ── SSM agent ─────────────────────────────────────────────────────────────────
# Ensure SSM is running before AAP attempts to connect via port forwarding
systemctl start amazon-ssm-agent
systemctl enable amazon-ssm-agent

# ── Runtime environment identity ──────────────────────────────────────────────
# Write environment context that AAP will use during its runtime config job.
# These are the only values that legitimately vary at runtime — everything
# else is baked into the AMI.
ENVIRONMENT="${environment}"        # injected by Terraform templatefile()
APP_VERSION="${app_version}"        # for display/audit purposes
INSTANCE_ID=$(curl -sf http://169.254.169.254/latest/meta-data/instance-id || echo "unknown")
ASG_NAME="${asg_name}"              # injected by Terraform templatefile()

hostnamectl set-hostname "liberty-app-$${INSTANCE_ID}"

# Write runtime context file — AAP reads this during its config job
# to know what environment it's configuring
mkdir -p /etc/liberty-demo
cat > /etc/liberty-demo/runtime-context.env << EOF
ENVIRONMENT=$${ENVIRONMENT}
APP_VERSION=$${APP_VERSION}
INSTANCE_ID=$${INSTANCE_ID}
ASG_NAME=$${ASG_NAME}
DEPLOYED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

chmod 644 /etc/liberty-demo/runtime-context.env

# ── Start Liberty ─────────────────────────────────────────────────────────────
# Liberty is fully installed in the AMI — just start the service.
# The ALB health check and AAP both need Liberty running before they proceed.
systemctl start liberty-base
systemctl enable liberty-base

# ── Wait for Liberty to be healthy ───────────────────────────────────────────
# Poll the health endpoint before signaling ready — ensures AAP connects
# to a running instance, and ensures ALB registers a healthy target.
echo "Waiting for Liberty health endpoint..."
SUCCESS=0
for i in $(seq 1 18); do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9080/liberty-demo/health || echo "000")
  echo "Attempt $i/18 — HTTP $HTTP_CODE"
  if [ "$HTTP_CODE" = "200" ]; then
    echo "Liberty is healthy"
    SUCCESS=1
    break
  fi
  sleep 10
done

if [ "$SUCCESS" != "1" ]; then
  echo "ERROR: Liberty failed to start — check /wslogs/liberty-base/messages.log"
  # Do not write the ready signal — Terraform will not trigger AAP
  # Instance will fail ALB health check and be replaced by ASG
  exit 1
fi

# ── Readiness signal ──────────────────────────────────────────────────────────
# Written only after Liberty is confirmed healthy.
# Terraform polls this via SSM before triggering the AAP runtime config job.
touch /tmp/userdata-complete

echo "=== User data complete ==="