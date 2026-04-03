#!/bin/sh

log() {
  printf '%b%s %b%s%b %s\n' \
    "${c1}" "${3:-->}" "${c3}${2:+$c2}" "$1" "${c3}" "$2" >&2
}

upgrade_system() {
  log "  Upgrading all system packages."
  export DEBIAN_FRONTEND=noninteractive
  apt-get -yq update >/dev/null
  apt-get -yq upgrade >/dev/null
}

install_packages() {
  log "  Installing the following packages: $*"
  export DEBIAN_FRONTEND=noninteractive
  apt-get -yq update >/dev/null
  apt-get -yq install "${@}" >/dev/null
}

wait_for_network() {
  log "  Checking network connectivity."
  while ! ping -c 1 -W 1 8.8.8.8 >/dev/null; do
    log "    Waiting for the network to be available..."
    sleep 1
  done
}

get_ec2_region() {
  local token
  token=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
  curl -s -H "X-aws-ec2-metadata-token: ${token}" \
    "http://169.254.169.254/latest/meta-data/placement/region"
}

get_ssm_parameter_value() {
  log "  Grabbing AWS Systems Manager Parameter Value for: ${1}"
  aws ssm get-parameter \
    --region "${AWS_DEFAULT_REGION}" \
    --name "${1}" \
    --query "Parameter.Value" \
    --with-decryption \
    --output text
}

set_ssm_parameter_value() {
  log "  Setting AWS Systems Manager Parameter Value for: ${1}"
  # Use --cli-input-json to prevent AWS CLI v2 from auto-fetching values that
  # begin with https:// (e.g. the TFE admin token URL).
  aws ssm put-parameter \
    --region "${AWS_DEFAULT_REGION}" \
    --cli-input-json "$(jq -n \
      --arg name "${1}" \
      --arg value "${2}" \
      '{"Name":$name,"Value":$value,"Type":"SecureString","Overwrite":true}')"
}

find_secretsmanager_secret() {
  log "  Looking up SecretsManager secret starting with: ${1}"
  aws secretsmanager list-secrets \
    --region "${AWS_DEFAULT_REGION}" \
    --query "SecretList[?starts_with(Name, '${1}')].Name" \
    --output text
}

get_secretsmanager_secret_value() {
  aws secretsmanager get-secret-value \
    --region "${AWS_DEFAULT_REGION}" \
    --secret-id "${1}" \
    --query SecretString --output text
}

set_ec2_http_put_response_hop_limit() {
  local aws_token ec2_instance_id
  aws_token=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
  ec2_instance_id=$(curl -s -H "X-aws-ec2-metadata-token: ${aws_token}" http://169.254.169.254/latest/meta-data/instance-id)
  aws ec2 modify-instance-metadata-options \
    --region "${AWS_DEFAULT_REGION}" \
    --instance-id "${ec2_instance_id}" \
    --http-tokens required \
    --http-endpoint enabled \
    --http-put-response-hop-limit "${1}" \
    >/dev/null 2>&1
}

get_ec2_private_ip_address() {
  local aws_token
  aws_token=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
  curl -s -H "X-aws-ec2-metadata-token: ${aws_token}" http://169.254.169.254/latest/meta-data/local-ipv4
}

main() {
  set -ef

  # Colors are automatically disabled if output is pipe/redirection.
  ! [ -t 2 ] || {
    c1='\033[1;33m'
    c2='\033[1;34m'
    c3='\033[m'
  }

  username="ubuntu"
  export AWS_DEFAULT_REGION
  AWS_DEFAULT_REGION="$(get_ec2_region)"

  log "Populating configuration variables."

  tfe_version="$(get_ssm_parameter_value "/TFE/TFE_VERSION")"
  postgresql_major_version="$(get_ssm_parameter_value "/TFE/POSTGRESQL_MAJOR_VERSION")"

  # App Settings
  tfe_encryption_password="$(get_ssm_parameter_value "/TFE/TFE_ENCRYPTION_PASSWORD")"
  tfe_hostname="$(get_ssm_parameter_value "/TFE/TFE_HOSTNAME")"
  tfe_license="$(get_ssm_parameter_value "/TFE/TFE_LICENSE")"

  # Database Settings
  tfe_database_host="$(get_ssm_parameter_value "/TFE/TFE_DATABASE_HOST")"
  tfe_database_name="$(get_ssm_parameter_value "/TFE/TFE_DATABASE_NAME")"
  tfe_database_user="$(get_ssm_parameter_value "/TFE/TFE_DATABASE_USER")"
  tfe_database_password="$(get_ssm_parameter_value "/TFE/TFE_DATABASE_PASSWORD")"

  # Redis Settings
  tfe_redis_host="$(get_ssm_parameter_value "/TFE/TFE_REDIS_HOST")"
  tfe_redis_password="$(get_ssm_parameter_value "/TFE/TFE_REDIS_PASSWORD")"

  # Object Storage Settings
  tfe_object_storage_s3_region="$(get_ssm_parameter_value "/TFE/TFE_OBJECT_STORAGE_S3_REGION")"
  tfe_object_storage_s3_bucket="$(get_ssm_parameter_value "/TFE/TFE_OBJECT_STORAGE_S3_BUCKET")"

  wait_for_network
  upgrade_system
  install_packages apt-transport-https ca-certificates curl gnupg unzip jq

  log "Updating the SSM Agent to the latest version."

  mkdir -p /tmp/ssm
  arch=$(dpkg --print-architecture)
  if curl -sSL "https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/ubuntu_${arch}/amazon-ssm-agent.deb" \
    -o /tmp/ssm/amazon-ssm-agent.deb 2>/dev/null; then
    dpkg -i /tmp/ssm/amazon-ssm-agent.deb >/dev/null 2>&1 || true
    systemctl enable amazon-ssm-agent
    systemctl restart amazon-ssm-agent
  else
    log "WARNING: Failed to download SSM agent. Continuing without update."
  fi
  rm -rf /tmp/ssm

  log "Setting up Docker."

  log "  Locating the Docker data disk."
  root_disk=$(lsblk -no PKNAME "$(findmnt -n -o SOURCE /)" 2>/dev/null || lsblk -dpno NAME | head -1)
  docker_disk=$(lsblk -dpno NAME,FSTYPE | awk -v root="/dev/${root_disk}" '$2 == "" && $1 != root { print $1; exit }')

  if [ -n "${docker_disk}" ]; then
    log "  Formatting ${docker_disk} as ext4 for Docker data."
    mkfs.ext4 -F "${docker_disk}" >/dev/null 2>&1

    mkdir -p /var/lib/docker

    docker_disk_uuid=$(blkid -s UUID -o value "${docker_disk}")
    printf 'UUID=%s /var/lib/docker ext4 defaults,nofail 0 2\n' "${docker_disk_uuid}" >>/etc/fstab
    mount /var/lib/docker
    log "  Mounted ${docker_disk} (UUID=${docker_disk_uuid}) at /var/lib/docker."
  else
    log "WARNING: No unformatted data disk found; Docker will use the root volume."
  fi

  # Setup Docker's APT repository.
  curl -fsSL "https://download.docker.com/linux/ubuntu/gpg" |
    gpg --yes --dearmor -o "/usr/share/keyrings/docker.gpg"

  chmod a+r /usr/share/keyrings/docker.gpg

  cat <<'EOF' >/etc/apt/sources.list.d/docker.sources
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: jammy
Components: stable
arch: amd64
signed-by: /usr/share/keyrings/docker.gpg
EOF

  # Enable ipv4 forwarding, required on CIS hardened machines.
  sysctl net.ipv4.conf.all.forwarding=1 >/dev/null 2>&1
  cat <<'EOF' >/etc/sysctl.d/enabled_ipv4_forwarding.conf
net.ipv4.conf.all.forwarding=1
EOF

  # Write /etc/docker/daemon.json before the packages are installed so Docker
  # picks up the configuration on its very first start.
  mkdir -p /etc/docker
  cat <<'EOF' >/etc/docker/daemon.json
{
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  }
}
EOF

  install_packages containerd.io docker-ce docker-ce-cli docker-compose-plugin

  # Add the ubuntu user to the docker group (created automatically as part of install).
  usermod -aG docker "${username}"

  # Explicitly start the Docker daemon and wait for it to be ready.
  log "  Starting the Docker daemon."
  systemctl enable --now docker

  log "  Waiting for the Docker daemon to be ready."
  local retries=30
  while ! docker info >/dev/null 2>&1; do
    retries=$((retries - 1))
    if [ "${retries}" -eq 0 ]; then
      log "ERROR: Docker daemon did not become ready in time. Daemon logs:"
      journalctl -u docker --no-pager -n 50 >&2
      exit 1
    fi
    sleep 2
  done


main "$@"
