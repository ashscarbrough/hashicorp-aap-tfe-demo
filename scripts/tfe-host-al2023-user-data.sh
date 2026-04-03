#!/bin/sh

log() {
  printf '%b%s %b%s%b %s\n' \
    "${c1}" "${3:-->}" "${c3}${2:+$c2}" "$1" "${c3}" "$2" >&2
}

upgrade_system() {
  log "  Upgrading all system packages."
  dnf upgrade -y >/dev/null
}

install_packages() {
  log "  Installing the following packages: $*"
  dnf install -y "${@}" >/dev/null
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

  username="ec2-user"
  export AWS_DEFAULT_REGION
  AWS_DEFAULT_REGION="$(get_ec2_region)"

  wait_for_network
  upgrade_system
  install_packages unzip jq

  log "Updating the SSM Agent to the latest version."
  dnf upgrade -y amazon-ssm-agent >/dev/null 2>&1 || \
    log "WARNING: Failed to update SSM agent. Continuing with existing version."
  systemctl enable amazon-ssm-agent
  systemctl restart amazon-ssm-agent


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

  # Write the Docker CE repo file explicitly pointing to CentOS 9 packages.
  # Using dnf config-manager --add-repo fails on AL2023 because it auto-detects
  # the OS version and constructs a path that does not exist on download.docker.com.
  cat <<'EOF' >/etc/yum.repos.d/docker-ce.repo
[docker-ce-stable]
name=Docker CE Stable - $basearch
baseurl=https://download.docker.com/linux/centos/9/$basearch/stable
enabled=1
gpgcheck=1
gpgkey=https://download.docker.com/linux/centos/gpg
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

}

main "$@"
