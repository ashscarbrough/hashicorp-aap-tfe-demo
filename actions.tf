
# Define an action to send a payload to AAP API.
# # 
# action "aap_job_launch" "run_playbook" {
#   config {
#     url    = "${var.aap_host}/api/controller/v2/job_templates/${var.aap_job_template_id}/launch/"
#     method = "POST"
#     request_headers = {
#       Authorization = "Bearer ${var.aap_token}"
#       Content-Type  = "application/json"
#     }
#     request_body = jsonencode({
#       inventory  = var.aap_inventory_id
#       extra_vars = {
#         target_host = aws_instance.main.public_ip
#       }
#     })
#   }
# }


# Define an action to send a payload to AAP API.
action "aap_job_launch" "run_playbook" {
  config {
    job_template_id     = var.aap_tf_actions_job_template_id
    wait_for_completion = true
    extra_vars = jsonencode({
      target_host = aws_instance.aap_tfe_demo_host.public_ip
    })
  }
}
