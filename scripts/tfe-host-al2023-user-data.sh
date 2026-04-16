#!/bin/sh
set -e

# Start nginx (was enabled at build time, just needs starting)
systemctl start nginx

# Wait for cloud-init to finish setting hostname
cloud-init status --wait

# Stamp the instance ID and hostname into the version page
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
HOSTNAME=$(hostname)

sed -i "s|Pending AAP configuration...|Pending AAP configuration — Instance: $INSTANCE_ID ($HOSTNAME) | IP: $PUBLIC_IP|g" \
  /usr/share/nginx/html/index.html