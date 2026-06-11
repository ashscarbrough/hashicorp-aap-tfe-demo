# resource "null_resource" "aap_inventory_sync" {
#     triggers = {
#         asg_desired_capacity = var.asg_desired_capacity
#         asg_id               = aws_autoscaling_group.al2023_aap_tfe_demo_asg.id
#     }


#     provisioner "local-exec" {
#         command = <<EOT
#         set -e
#         echo "Triggering AAP inventory sync for ASG ${self.triggers.asg_id} with desired capacity ${self.triggers.asg_desired_capacity}"

#         SYNC_ID=$(curl -s \
#             --insecure \
#             --request POST \
#             --header "Authorization: Bearer ${var.aap_api_token}" \
#             --header "Content-Type: application/json" \
#             "${}
#         -X POST "https://<AAP_URL>/api/v2/inventory_sources/${var.aap_inventory_source_id}/update_inventory/" \
#             -H "Content-Type: application/json" \
#             -d '{"extra_vars": {"asg_id": "${self.triggers.asg_id}", "desired_capacity": "${self.triggers.asg_desired_capacity}"}}')


#         EOT
#     }

#     depends_on = [aws_autoscaling_group.aap_demo]
# }
  