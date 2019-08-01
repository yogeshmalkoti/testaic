# Project AIC

The terraform script will create instances across the region  , roles to access s3 bucket, security group, gateway , loadbalancer , subnets etc all in one go. 
1. Specify the variables in var.tf
2. Export credentials   
   export AWS_ACCESS_KEY_ID="XXXXXXXXXXXXXX"
   export AWS_SECRET_ACCESS_KEY="XXXXXXXXXXXXXXXXXXXXXXXXXX"
   export AWS_DEFAULT_REGION="ap-southeast-1"

3. terraform apply # to provision
4. terraform destroy # to destroy