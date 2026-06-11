action "aap_job_launch" "install_packages" {
  config {
    job_template_id     = 18
    wait_for_completion = true
    extra_vars = jsonencode({
      packages = var.packages_to_install
    })
  }
}

# action "aap_job_launch" "security_package_install" {
#   config {
#     job_template_id     = 15
#     wait_for_completion = true
#     extra_vars = jsonencode({
#       target_host = aws_eip.aap_tfe_demo_host.public_ip
#     })
#   }
# }

# action "aap_job_launch" "runtime_package_install" {
#   config {
#     job_template_id     = 16
#     wait_for_completion = true
#     extra_vars = jsonencode({
#       target_host = aws_eip.aap_tfe_demo_host.public_ip
#     })
#   }
# }

# action "aap_job_launch" "observability_package_install" {
#   config {
#     job_template_id     = 17
#     wait_for_completion = true
#     extra_vars = jsonencode({
#       target_host = aws_eip.aap_tfe_demo_host.public_ip
#     })
#   }
# }
