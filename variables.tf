variable "aws_regions" {
  default = "ap-south-1"
}

variable "subnet_az" {
  default = "ap-south-1a"
}

#### SG related variables #####
variable "app_cidr" {
  default = "0.0.0.0/0"
}

variable "port_sg" {
  type        = list(number)
  description = "List of 80 & 443 ingress ports"
  default     = [80, 22]
}

variable "web_sg" {
  default = "Web_server_sg"
}

variable "app_sg" {
  default = "app_server_sg"
}

###### Ec2 related variables #######
variable "ami_owners" {
  //type = string
  default = "amazon"
}
variable "OS_Archtiecture" {
  default = "x86_64"
}
variable "ami_name" {
  type    = string
  default = "amzn2-ami-hvm-2.0*"
}

#### Key pair #####
variable "keyname" {
  default = "dvt_tools"
}

variable "pub_key" {
  default = ".ssh/dev-tools.pub"
}

variable "count_instance" {
  type    = number
  default = 2
}

variable "tags" {
  type    = list
  default = ["appserver1", "appserver2"]
}

variable "app_server" {
  default = "./scripts/app_server.sh"
}
