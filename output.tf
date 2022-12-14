# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# DataSunrise Cluster for Amazon Web Services
# Version 0.1
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

output "DataSunriseConsoleURL" {
  value = "https://${aws_lb.ds_ntwrk_load_balancer.dns_name}:11000"
}

output "NLBProxyEndpoint" {
  value = aws_lb.ds_ntwrk_load_balancer.dns_name
}

output "NLBProxyPort" {
  value = var.ds_instance_port
}

output "SecurityGroupId" {
  value = aws_security_group.ec2sg.id
}

output "SecurityGroupVpcId" {
  value = aws_security_group.ec2sg.vpc_id
}

output "SecurityGroupUrl" {
  value = "https://console.aws.amazon.com/ec2/v2/home?region=${data.aws_region.current.name}#SecurityGroups:search=${aws_security_group.ec2sg.id};sort=groupId"
}