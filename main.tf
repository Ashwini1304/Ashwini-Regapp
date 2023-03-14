terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region     = "ap-southeast-1"
  access_key = "AKIAWGKGU455QFOBG6AD"
  secret_key = "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"
}

resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "myvpc"
  }
}
resource "aws_subnet" "my_subnet" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-southeast-1a"

  tags = {
    Name = "Public_Subnet"
  }
}
resource "aws_subnet" "my_subnet1" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-southeast-1b"
  tags = {
    Name = "Private_Subnet"
  }
}
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "Project VPC IG"
  }
}
resource "aws_route_table" "first_rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "first Route Table"
  }
}
resource "aws_route_table_association" "public_subnet_asso" {
  subnet_id      = aws_subnet.my_subnet.id
  route_table_id = aws_route_table.first_rt.id
}
resource "aws_route_table" "second_rt" {
  vpc_id = aws_vpc.my_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.NAT.id
  }
  tags = {
    Name = "second Route Table"
  }
}
resource "aws_route_table_association" "private_subnet_asso" {
  subnet_id      = aws_subnet.my_subnet1.id
  route_table_id = aws_route_table.second_rt.id
}

resource "aws_eip" "nat_gateway" {
  vpc = true
}
resource "aws_nat_gateway" "NAT" {
  allocation_id = aws_eip.nat_gateway.id
  subnet_id     = aws_subnet.my_subnet.id

  tags = {
    Name = "gw NAT"
  }
}
resource "aws_instance" "web_instance" {
  ami                         = "ami-064eb0bee0c5402c5"
  instance_type               = "t2.micro"
  key_name                    = "Key_Pair"
  subnet_id                   = aws_subnet.my_subnet.id
  associate_public_ip_address = true
  security_groups = [aws_security_group.web_traffic.id]
user_data              = <<EOF
#!/bin/bash
    yum update -y
     yum update –y
    wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
    rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
    yum upgrade -y
    amazon-linux-extras install java-openjdk11 -y
    yum install jenkins -y
    systemctl enable jenkins
    systemctl start jenkins
sudo yum install docker -y
sudo service docker start
sudo cd /opt
sudo wget https://dlcdn.apache.org/maven/maven-3/3.9.0/binaries/apache-maven-3.9.0-bin.tar.gz
sudo tar -xvzf apache-maven-3.9.0-bin.tar.gz
sudo mv apache-maven-3.9.0 /opt/maven
    EOF
   tags={
    Name="Jenkins-Server"
   }
    }

resource "aws_instance" "web_instance2" {
  ami                         = "ami-082b1f4237bd816a1"
  instance_type               = "t2.medium"
  key_name                    = "Key_Pair"
  subnet_id                   = aws_subnet.my_subnet1.id
  associate_public_ip_address = false
user_data              = <<EOF
#!/bin/bash
sudo apt update && apt -y install docker.io
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl && chmod +x ./kubectl && sudo mv ./kubectl /usr/local/bin/kubectl
curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-latest-amd64 && chmod +x minikube && sudo mv minikube /usr/local/bin/
apt install conntrack
minikube start --vm-driver=none
minikube status
EOF

  tags = {
    "Name" : "Minikube-Server"
}
}
variable "ingressports" {
  type    = list(number)
  default = [8080, 22]
}

resource "aws_security_group" "web_traffic" {
  name        = "Allow web traffic"
  description = "inbound ports for ssh and standard http and everything outbound"
  vpc_id = aws_vpc.my_vpc.id
  dynamic "ingress" {
    for_each = var.ingressports
    content {
      protocol    = "tcp"
      from_port   = ingress.value
      to_port     = ingress.value
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    "Name"      = "Jenkins-sg"
    "Terraform" = "true"
  }
}


