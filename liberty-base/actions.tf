# -------------------------------------------------------------
# SSM Run Command action example — not currently used, but left here for reference.
# This action points at a job template that executes an Ansible playbook using the SSM
# connection plugin, allowing for configuration of the instance without SSH connectivity.
# Note that the playbook itself must be designed to work with the connection plugin, and
# the instance must have the appropriate IAM permissions and SSM agent installed.
# -------------------------------------------------------------

action "aap_workflow_job_launch" "current_version_playbook_ssm" {
  config {
    workflow_job_template_id     = var.aap_current_app_version_job_template_id
    wait_for_completion = true
    extra_vars = jsonencode({
      ssm_instance_id              = aws_instance.liberty_base_host.id
      aws_region                   = var.aws_region
      ansible_python_interpreter   = "/usr/bin/python3"
    })
  }
}

# Rollback action — triggered manually from the HCP Terraform UI.
# Points at the configure_demo_instance_v1.2.0.yml job template in AAP.
# The version to restore is determined by the job template itself — no extra vars required.
action "aap_workflow_job_launch" "previous_version_rollback_playbook" {
  config {
    workflow_job_template_id     = var.aap_previous_version_rollback_job_template_id
    wait_for_completion = true
    extra_vars = jsonencode({
      ssm_instance_id              = aws_instance.liberty_base_host.id
      aws_region                   = var.aws_region
      ansible_python_interpreter   = "/usr/bin/python3"
    })
  }
}

