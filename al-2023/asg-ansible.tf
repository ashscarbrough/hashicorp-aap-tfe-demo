# The null_resource IS the fleet state representation
# When it changes, the fleet changed, so AAP should run
resource "null_resource" "asg_fleet_state" {
  triggers = {
    # Fleet changed if any of these changed
    desired_capacity = var.asg_desired_capacity
    ami_id           = data.hcp_packer_artifact.al2023_demo.external_identifier
    asg_id           = aws_autoscaling_group.al2023_aap_tfe_demo_asg.id
  }

  # Wait for instances to be healthy before firing action
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "Waiting for ASG fleet to be healthy..."

      while true; do
        HEALTHY=$(aws elbv2 describe-target-health \
          --target-group-arn ${aws_lb_target_group.al2023_aap_tfe_demo_tg.arn} \
          --region ${var.aws_region} \
          --query 'length(TargetHealthDescriptions[?TargetHealth.State==`healthy`])' \
          --output text)

        echo "Healthy: $HEALTHY / ${var.asg_desired_capacity}"

        if [ "$HEALTHY" -ge "${var.asg_desired_capacity}" ]; then
          echo "Fleet is healthy"
          break
        fi
        sleep 15
      done

      # Register all instances in AAP inventory
      INSTANCES=$(aws ec2 describe-instances \
        --filters \
          "Name=tag:aws:autoscaling:groupName,Values=${aws_autoscaling_group.al2023_aap_tfe_demo_asg.name}" \
          "Name=instance-state-name,Values=running" \
        --region ${var.aws_region} \
        --query 'Reservations[].Instances[].[InstanceId,PublicIpAddress]' \
        --output text)

      # Clear existing hosts
      EXISTING=$(curl -s --insecure \
        --header "Authorization: Bearer $${AAP_TOKEN}" \
        "${var.aap_hostname}/api/controller/v2/inventories/${var.asg_aap_inventory_id}/hosts/" \
        | jq -r '.results[].id')

      for HOST_ID in $EXISTING; do
        curl -s --insecure --request DELETE \
          --header "Authorization: Bearer $${AAP_TOKEN}" \
          "${var.aap_hostname}/api/controller/v2/hosts/$HOST_ID/"
      done

      # Register current instances
      echo "$INSTANCES" | while read INSTANCE_ID PUBLIC_IP; do
        [ -z "$INSTANCE_ID" ] && continue
        curl -s --insecure --request POST \
          --header "Authorization: Bearer $${AAP_TOKEN}" \
          --header "Content-Type: application/json" \
          --data "{
            \"name\": \"$INSTANCE_ID\",
            \"inventory\": ${var.asg_aap_inventory_id},
            \"variables\": \"{\\\"ansible_host\\\": \\\"$PUBLIC_IP\\\", \\\"ansible_user\\\": \\\"ec2-user\\\", \\\"ansible_ssh_common_args\\\": \\\"-o StrictHostKeyChecking=no\\\", \\\"instance_id\\\": \\\"$INSTANCE_ID\\\"}\"
          }" \
          "${var.aap_hostname}/api/controller/v2/hosts/"
      done

      echo "Fleet registration complete"
    EOT

    environment = {
      AAP_TOKEN = var.aap_token
    }
  }

  depends_on = [aws_autoscaling_group.al2023_aap_tfe_demo_asg]

  # THIS is where Terraform Actions stay in the picture
  lifecycle {
    action_trigger {
      events  = [after_create, after_update]
      actions = [action.al2023_aap_tfe_demo_job_launch.configure_fleet]
    }
  }
}