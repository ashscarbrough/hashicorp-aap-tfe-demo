#!/bin/sh
set -e

# Start nginx (was enabled at build time, just needs starting)
systemctl start nginx

# Stamp the instance ID and hostname into the version page
IMDS_BASE="http://169.254.169.254/latest"
IMDS_TOKEN=$(curl -s -m 2 -X PUT "${IMDS_BASE}/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" || true)

read_imds() {
  path="$1"
  if [ -n "${IMDS_TOKEN}" ]; then
    curl -s -f -m 2 -H "X-aws-ec2-metadata-token: ${IMDS_TOKEN}" "${IMDS_BASE}/${path}" || true
  else
    curl -s -f -m 2 "${IMDS_BASE}/${path}" || true
  fi
}

INSTANCE_ID=$(read_imds "meta-data/instance-id")
PUBLIC_IP=$(read_imds "meta-data/public-ipv4")
HOSTNAME=$(hostname 2>/dev/null || true)

[ -n "${INSTANCE_ID}" ] || INSTANCE_ID="unknown-instance"
[ -n "${PUBLIC_IP}" ] || PUBLIC_IP="no-public-ip"
[ -n "${HOSTNAME}" ] || HOSTNAME="unknown-host"

RUNTIME_STATUS="Pending AAP configuration... Instance: ${INSTANCE_ID} (${HOSTNAME}) - IP: ${PUBLIC_IP}"
RUNTIME_STATUS_ESCAPED=$(printf '%s' "${RUNTIME_STATUS}" | sed 's/[&|]/\\&/g')

sed -i "s|Pending AAP configuration...|${RUNTIME_STATUS_ESCAPED}|g" \
  /usr/share/nginx/html/index.html