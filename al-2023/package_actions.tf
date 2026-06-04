action "aap_job_launch" "essentials_package_install" {
  config {
    job_template_id     = 14
    wait_for_completion = true
    extra_vars = jsonencode({
      target_host = aws_eip.aap_tfe_demo_host.public_ip
    })
  }
}

action "aap_job_launch" "security_package_install" {
  config {
    job_template_id     = 15
    wait_for_completion = true
    extra_vars = jsonencode({
      target_host = aws_eip.aap_tfe_demo_host.public_ip
    })
  }
}

action "aap_job_launch" "runtime_package_install" {
  config {
    job_template_id     = 16
    wait_for_completion = true
    extra_vars = jsonencode({
      target_host = aws_eip.aap_tfe_demo_host.public_ip
    })
  }
}

action "aap_job_launch" "observability_package_install" {
  config {
    job_template_id     = 17
    wait_for_completion = true
    extra_vars = jsonencode({
      target_host = aws_eip.aap_tfe_demo_host.public_ip
    })
  }
}
