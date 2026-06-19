action "aap_job_launch" "install_packages" {
  config {
    job_template_id     = 18
    wait_for_completion = true
    extra_vars = jsonencode({
      packages = var.packages_to_install
    })
  }
}
