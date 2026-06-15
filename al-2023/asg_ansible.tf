# ------------------------------------------------------------------------------
# ASG Instances as AAP Hosts
# ------------------------------------------------------------------------------

# Discovers ASG instances after scaling
data "aws_instances" "al2023_asg" {
  filter {
    name   = "tag:aws:autoscaling:groupName"
    values = [aws_autoscaling_group.al2023_aap_tfe_demo_asg.name]
  }
  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
  depends_on = [aws_autoscaling_group.al2023_aap_tfe_demo_asg]
}

# Registers each instance as an AAP host
resource "aap_host" "asg_instances" {
  for_each = toset(data.aws_instances.al2023_asg.ids)

  name         = each.value
  inventory_id = var.asg_aap_inventory_id

  variables = jsonencode({
    ansible_host            = data.aws_instances.al2023_asg.public_ips[index(data.aws_instances.al2023_asg.ids, each.value)]
    ansible_user            = "ec2-user"
    ansible_ssh_common_args = "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
    instance_id             = each.value
    asg_name                = aws_autoscaling_group.al2023_aap_tfe_demo_asg.name
  })
}
