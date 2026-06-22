#!/bin/bash
exec > >(tee /var/log/user-data.log) 2>&1

echo "=== User data start ==="

# ── CloudWatch log setup ──────────────────────────────────────────────────────
LOG_GROUP="/liberty-base/userdata"
LOG_STREAM="$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
REGION="us-east-1"

# Create log group and stream if they don't exist
aws logs create-log-group --log-group-name "$LOG_GROUP" --region "$REGION" 2>/dev/null || true
aws logs create-log-stream --log-group-name "$LOG_GROUP" --log-stream-name "$LOG_STREAM" --region "$REGION" 2>/dev/null || true

# Function to send a log line to CloudWatch
cw_log() {
  local MESSAGE="$1"
  local TIMESTAMP=$(date +%s%3N)
  echo "$MESSAGE"
  aws logs put-log-events \
    --log-group-name "$LOG_GROUP" \
    --log-stream-name "$LOG_STREAM" \
    --log-events "timestamp=$${TIMESTAMP},message=$${MESSAGE}" \
    --region "$REGION" 2>/dev/null || true
}

cw_log "=== User data start ==="

# Set hostname
hostnamectl set-hostname liberty-mutable-demo
cw_log "Hostname set to liberty-mutable-demo"

# Wait for network
sleep 10
cw_log "Network settle wait complete"

# Enable SSM agent
systemctl enable amazon-ssm-agent
cw_log "SSM agent enabled"

# Start SSM agent with retries
for i in {1..5}; do
  if systemctl start amazon-ssm-agent; then
    cw_log "SSM agent started successfully on attempt $i"
    break
  fi
  cw_log "SSM agent start attempt $i failed, retrying in 10s..."
  sleep 10
done

# Log SSM agent status
SSM_STATUS=$(systemctl status amazon-ssm-agent --no-pager 2>&1 || true)
cw_log "SSM agent status: $SSM_STATUS"

# Log SSM agent log tail
SSM_LOG=$(tail -50 /var/log/amazon/ssm/amazon-ssm-agent.log 2>/dev/null || echo "No SSM log found")
cw_log "SSM agent log: $SSM_LOG"

touch /tmp/userdata-complete
cw_log "=== User data complete ==="