############################################################
# Outputs
############################################################

output "master_public_ip" {
  description = "Master node public IP  "
  value       =  aws_instance.master.public_ip
}






