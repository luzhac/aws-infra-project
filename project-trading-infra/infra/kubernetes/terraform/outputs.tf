output "nat_public_ip" {
  value       = aws_eip.nat_eip.public_ip
  description = "Public EIP for NAT/Bastion (SSH)"
}

output "master_private_ip" { value = aws_instance.master.private_ip }
output "worker_private_ip" { value = aws_instance.worker.private_ip }
output "app2_private_ip"   { value = aws_instance.app2.private_ip }

output "efs_id" { value = aws_efs_file_system.efs.id }

output "ssh_examples" {
  value = <<EOT
# SSH into NAT/Bastion
ssh -i ${local_file.private_key_pem.filename} ec2-user@${aws_eip.nat_eip.public_ip}

# From Bastion to cluster:
ssh ec2-user@${aws_instance.master.private_ip}
ssh ec2-user@${aws_instance.worker.private_ip}
ssh ec2-user@${aws_instance.app2.private_ip}
EOT
}
