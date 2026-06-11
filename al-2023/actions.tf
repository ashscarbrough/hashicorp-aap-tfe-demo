
# Define an action to send a payload to AAP API.
action "aap_job_launch" "run_new_version_playbook" {
  config {
    job_template_id     = var.aap_new_version_job_template_id
    wait_for_completion = true
    extra_vars = jsonencode({
      target_host = aws_eip.aap_tfe_demo_host.public_ip
    })
  }
}

# Rollback action — triggered manually from the HCP Terraform UI.
# Points at the configure_demo_instance_v1.2.0.yml job template in AAP.
# The version to restore is determined by the job template itself — no extra vars required.
action "aap_job_launch" "rollback_playbook" {
  config {
    job_template_id     = var.aap_rollback_job_template_id
    wait_for_completion = true
    extra_vars = jsonencode({
      target_host = aws_eip.aap_tfe_demo_host.public_ip
    })
  }
}

# -------------------------------------------------------------
# SSM Run Command action example — not currently used, but left here for reference.
# This action points at a job template that executes an Ansible playbook using the SSM
# connection plugin, allowing for configuration of the instance without SSH connectivity.
# Note that the playbook itself must be designed to work with the connection plugin, and
# the instance must have the appropriate IAM permissions and SSM agent installed.
# -------------------------------------------------------------

# action "aap_job_launch" "ssm_run_new_version_playbook_ssm" {
#   config {
#     job_template_id     = 20
#     wait_for_completion = true
#     extra_vars = jsonencode({
#       target_host                  = aws_instance.aap_tfe_demo_host.public_ip
#       ssm_instance_id              = aws_instance.aap_tfe_demo_host.id
#       aws_region                   = var.aws_region
#       ssm_bucket_name              = var.ssm_output_s3_bucket
#       ansible_python_interpreter   = "/usr/bin/python3"
#     })
#   }
# }

# # Rollback action — triggered manually from the HCP Terraform UI.
# # Points at the configure_demo_instance_v1.2.0.yml job template in AAP.
# # The version to restore is determined by the job template itself — no extra vars required.
# action "aap_job_launch" "ssm_rollback_playbook" {
#   config {
#     job_template_id     = 21
#     wait_for_completion = true
#     extra_vars = jsonencode({
#       target_host = aws_eip.aap_tfe_demo_host.public_ip
#     })
#   }
# }

