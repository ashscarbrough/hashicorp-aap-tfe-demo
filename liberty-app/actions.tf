# -------------------------------------------------------------
# SSM Run Command action example — not currently used, but left here for reference.
# This action points at a job template that executes an Ansible playbook using the SSM
# connection plugin, allowing for configuration of the instance without SSH connectivity.
# Note that the playbook itself must be designed to work with the connection plugin, and
# the instance must have the appropriate IAM permissions and SSM agent installed.
# -------------------------------------------------------------

action "aap_job_launch" "configure_application_ssm" {
  config {
    job_template_id = var.aap_configuration_job_template_id
    wait_for_completion = true
    wait_for_completion_timeout_seconds = 300 # 5 minute timeout for playbook completion, adjust as needed
    extra_vars = jsonencode({
      aws_region                   = var.aws_region
      alb_dns_name                 = aws_lb.liberty_app.dns_name
      ansible_python_interpreter   = "/usr/bin/python3"
      ansible_user                 = "ssm-user"
      liberty_server_name          = "liberty-app"
    })
  }
}

action "aap_job_launch" "install_packages" {
  config {
    job_template_id     = 18
    wait_for_completion = true
    extra_vars = jsonencode({
      packages = var.packages_to_install
    })
  }
}
