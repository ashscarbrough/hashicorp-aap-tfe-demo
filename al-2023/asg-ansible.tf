# ------------------------------------------------------------------------------
# ASG Instances as AAP Hosts
# ------------------------------------------------------------------------------

# # Discovers ASG instances after scaling
# data "aws_instances" "al2023_asg" {
#   filter {
#     name   = "tag:aws:autoscaling:groupName"
#     values = [aws_autoscaling_group.al2023_aap_tfe_demo_asg.name]
#   }
#   filter {
#     name   = "instance-state-name"
#     values = ["running"]
#   }
#   depends_on = [aws_autoscaling_group.al2023_aap_tfe_demo_asg]
# }

# # Registers each instance as an AAP host
# resource "aap_host" "asg_instances" {
#   for_each = toset(data.aws_instances.al2023_asg.ids)

#   name         = each.value
#   inventory_id = var.asg_aap_inventory_id

#   variables = jsonencode({
#     ansible_host            = data.aws_instances.al2023_asg.public_ips[index(data.aws_instances.al2023_asg.ids, each.value)]
#     ansible_user            = "ec2-user"
#     ansible_ssh_common_args = "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
#     instance_id             = each.value
#     asg_name                = aws_autoscaling_group.al2023_aap_tfe_demo_asg.name
#   })
# }


resource "null_resource" "register_asg_hosts" {
  triggers = {
    asg_desired_capacity = var.asg_desired_capacity
    asg_name             = aws_autoscaling_group.al2023_aap_tfe_demo_asg.name
    ami_id               = data.hcp_packer_artifact.al2023_demo.external_identifier
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e

      echo "Waiting for ASG instances to be running..."
      sleep 60

      # Get running instance IDs and IPs from ASG
      INSTANCES=$(aws ec2 describe-instances \
        --filters \
          "Name=tag:aws:autoscaling:groupName,Values=${aws_autoscaling_group.al2023_aap_tfe_demo_asg.name}" \
          "Name=instance-state-name,Values=running" \
        --region ${var.aws_region} \
        --query 'Reservations[].Instances[].[InstanceId,PublicIpAddress]' \
        --output text)

      echo "Found instances:"
      echo "$INSTANCES"

      # First remove all existing hosts from this ASG in AAP inventory
      EXISTING_HOSTS=$(curl -s --insecure \
        --header "Authorization: Bearer $${AAP_TOKEN}" \
        "${var.aap_hostname}/api/controller/v2/inventories/${var.asg_aap_inventory_id}/hosts/" \
        | jq -r '.results[].id')

      for HOST_ID in $EXISTING_HOSTS; do
        echo "Removing stale host: $HOST_ID"
        curl -s --insecure \
          --request DELETE \
          --header "Authorization: Bearer $${AAP_TOKEN}" \
          "${var.aap_hostname}/api/controller/v2/hosts/$HOST_ID/"
      done

      # Register each current ASG instance as an AAP host
      echo "$INSTANCES" | while read INSTANCE_ID PUBLIC_IP; do
        if [ -z "$INSTANCE_ID" ] || [ -z "$PUBLIC_IP" ]; then
          continue
        fi

        echo "Registering host: $INSTANCE_ID ($PUBLIC_IP)"

        curl -s --insecure \
          --request POST \
          --header "Authorization: Bearer $${AAP_TOKEN}" \
          --header "Content-Type: application/json" \
          --data "{
            \"name\": \"$INSTANCE_ID\",
            \"inventory\": ${var.asg_aap_inventory_id},
            \"variables\": \"{\\\"ansible_host\\\": \\\"$PUBLIC_IP\\\", \\\"ansible_user\\\": \\\"ec2-user\\\", \\\"ansible_ssh_common_args\\\": \\\"-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null\\\", \\\"instance_id\\\": \\\"$INSTANCE_ID\\\", \\\"asg_name\\\": \\\"${aws_autoscaling_group.al2023_aap_tfe_demo_asg.name}\\\"}\"
          }" \
          "${var.aap_hostname}/api/controller/v2/hosts/"
      done

      echo "Host registration complete"
    EOT

    environment = {
      AAP_TOKEN = var.aap_token
    }
  }

  depends_on = [aws_autoscaling_group.al2023_aap_tfe_demo_asg]
}