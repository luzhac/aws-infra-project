terraform init
terraform apply -auto-approve 


icacls "C:\Myfiles\MyProjects\aws-infra-lab\terraform\ec2-manual-cluster\cka-key.pem" /inheritance:r
icacls "C:\Myfiles\MyProjects\aws-infra-lab\terraform\ec2-manual-cluster\cka-key.pem" /grant:r "$($env:USERNAME):R"


ssh -i cka-key.pem ubuntu@13.221.190.84

ssh -i cka-key.pem ubuntu@54.167.23.189
ssh -i cka-key.pem ubuntu@54.89.216.173


# win 11
aws eks update-kubeconfig --region us-east-1 --name cka-practice-cluster
aws sts get-caller-identity     

