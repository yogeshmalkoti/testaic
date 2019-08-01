variable "public_key_path" {
  description = <<DESCRIPTION
Path to the SSH public key to be used for authentication.
Ensure this keypair is added to your local SSH agent so provisioners can
connect.

Example: ~/.ssh/terraform.pub
DESCRIPTION
 default = "/home/ec2-user/newpub.key"
}

variable "tag" {
  type = string
  default = "aic"

}

variable "key_name" {
  description = "Desired name of AWS key pair"
  default = "aicpair"
}

variable "aws_region" {
  description = "AWS region to launch servers."
  default     = "ap-southeast-1"
}

variable "aws_amis" {
  default = {
    ap-southeast-1 = "ami-01b02e6dd3efebd61"
  }
}

variable "private_subnet" {
  type    = list(string)
  default = ["10.0.1.0/24","10.0.2.0/24","10.0.3.0/24"]
}

variable "aws_zones" {
  type = list(string)
  default = ["ap-southeast-1a","ap-southeast-1b","ap-southeast-1c"]
}
