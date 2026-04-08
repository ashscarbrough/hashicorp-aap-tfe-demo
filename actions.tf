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