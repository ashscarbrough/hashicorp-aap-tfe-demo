
# # Define an action to send a payload to AAP API.
# action "aap_job_launch" "run_new_version_playbook" {
#   config {
#     job_template_id     = var.aap_new_version_job_template_id
#     wait_for_completion = true
#     extra_vars = jsonencode({
#       target_host = aws_eip.aap_tfe_demo_host.public_ip
#     })
#   }
# }

# # Rollback action — triggered manually from the HCP Terraform UI.
# # Points at the configure_demo_instance_v1.2.0.yml job template in AAP.
# # The version to restore is determined by the job template itself — no extra vars required.
# action "aap_job_launch" "rollback_playbook" {
#   config {
#     job_template_id     = var.aap_rollback_job_template_id
#     wait_for_completion = true
#     extra_vars = jsonencode({
#       target_host = aws_eip.aap_tfe_demo_host.public_ip
#     })
#   }
# }
