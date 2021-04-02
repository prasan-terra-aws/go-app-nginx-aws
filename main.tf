terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>3.0"
    }
  }
}

######### Provider Block ########
provider "aws" {
  region = var.aws_regions
  //  profile = var.prf
}

##### Fetching VPC ID #####
data "aws_vpc" "main_vpc" {
  default = "true"
}

###### Fetching subnet ########
data "aws_subnet" "subnet" {
  vpc_id            = data.aws_vpc.main_vpc.id
  availability_zone = var.subnet_az
}

###### Web server SG ##################
resource "aws_security_group" "web_sg" {
  name   = var.web_sg
  vpc_id = data.aws_vpc.main_vpc.id

  dynamic "ingress" {
    for_each = var.port_sg
    iterator = port
    content {
      from_port   = port.value
      to_port     = port.value
      protocol    = "tcp"
      cidr_blocks = [var.app_cidr]
    }
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = var.web_sg
  }
}

############# Application server SG ###############
resource "aws_security_group" "app_sg" {
  name       = var.app_sg
  vpc_id     = data.aws_vpc.main_vpc.id
  depends_on = [aws_security_group.web_sg]
  ingress {
    self      = true
    from_port = 8484
    to_port   = 8484
    protocol  = "tcp"
  }

  ingress {
    cidr_blocks = [var.app_cidr]
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = var.app_sg
  }
}

#### Attaching App server security group with Web server security #####
resource "aws_security_group_rule" "sg_web_app1" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = -1
  depends_on               = [aws_security_group.web_sg, aws_security_group.app_sg]
  security_group_id        = aws_security_group.app_sg.id
  source_security_group_id = aws_security_group.web_sg.id
}

resource "aws_security_group_rule" "sg_web_app2" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  depends_on               = [aws_security_group.web_sg, aws_security_group.app_sg]
  security_group_id        = aws_security_group.app_sg.id
  source_security_group_id = aws_security_group.web_sg.id
}

########### Webserver creation #################
##### Fecthing AMI ID ###########
data "aws_ami" "Go_app_ami" {
  most_recent = true
  owners      = [var.ami_owners]

  filter {
    name   = "architecture"
    values = [var.OS_Archtiecture]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "name"
    values = [var.ami_name]
  }
}

#### Key pair creation #######
resource "aws_key_pair" "devkey" {
  key_name   = var.keyname
  public_key = file(var.pub_key)
}

##### Provisioning Ec2 Instance ###########
######## Web server provision#########
resource "aws_instance" "webserver" {
  key_name                    = aws_key_pair.devkey.key_name
  ami                         = data.aws_ami.Go_app_ami.id
  instance_type               = "t2.micro"
  subnet_id                   = data.aws_subnet.subnet.id
  iam_instance_profile        = "Ec2-s3"
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = "true"
  depends_on                  = [aws_security_group.web_sg, aws_instance.appserver]
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file(".ssh/dev-tools.ppk")
    host        = self.public_ip
  }
  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y && sudo amazon-linux-extras install nginx1 -y",
      "sudo sleep 10",
      "sudo echo '==============================='",
      "sudo systemctl enable nginx",
      "sudo systemctl stop nginx"
    ]
  }
  tags = {
    Name = "Webserver"
  }
}

######## App server provision#########
resource "aws_instance" "appserver" {
  count                       = var.count_instance
  key_name                    = aws_key_pair.devkey.key_name
  ami                         = data.aws_ami.Go_app_ami.id
  instance_type               = "t2.micro"
  subnet_id                   = data.aws_subnet.subnet.id
  iam_instance_profile        = "Ec2-s3"
  depends_on                  = [aws_security_group.web_sg, aws_security_group.app_sg]
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  associate_public_ip_address = "true"
  user_data                   = file(var.app_server)
  tags = {
    Name = element(var.tags, count.index)
  }
}

########## Null resource for the configuration ###############
######### Getting app server ip's ###########

resource "null_resource" "app_ips" {
  depends_on = [aws_instance.appserver, aws_instance.webserver]
  provisioner "local-exec" {
    command = "echo '${join("\n", formatlist("%s", aws_instance.appserver[*].private_ip))}' >> ./output/host_ips.txt"
  }
  provisioner "local-exec" {
    command = "/bin/bash ./scripts/app_nginx_config.sh"
  }
}

######### Binding app server with web server nginx configuration ###########
resource "null_resource" "web_app_binding" {
  depends_on = [aws_instance.appserver, aws_instance.webserver, null_resource.app_ips]
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file(".ssh/dev-tools.ppk")
    host        = aws_instance.webserver.public_ip
  }
  provisioner "file" {
    source      = "./scripts/nginx.conf"
    destination = "/tmp/nginx.conf"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bkp",
      "sudo cp /tmp/nginx.conf /etc/nginx/nginx.conf",
      "sudo chmod 664 /etc/nginx/nginx.conf",
      "sudo systemctl start nginx"
    ]
  }
}
