output "instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.web.id
}

output "public_ip" {
  description = "EC2 Public IP"
  value       = aws_instance.web.public_ip
}

output "ssh_command" {
  description = "SSH command (use your private key path)"
  value       = "ssh -i ~/.ssh/id_rsa ec2-user@${aws_instance.web.public_ip}"
}
