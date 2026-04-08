
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
