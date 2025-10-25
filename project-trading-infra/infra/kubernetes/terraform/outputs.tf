############################################################
# Outputs
############################################################

output "master_public_ip" {
  description = "Master node public IP (Elastic IP)"
  value       = aws_eip.master_eip.public_ip
}




output "monitor_private_ip" {
  description = "Private IP of monitor node"
  value       = aws_instance.monitor.private_ip
}


