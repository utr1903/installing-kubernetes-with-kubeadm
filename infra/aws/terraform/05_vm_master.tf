##################
### Master VMs ###
##################

# Security group - Master
resource "aws_security_group" "master" {
  name        = "k8s_master"
  description = "Allow inbound traffic for master nodes"
  vpc_id      = aws_vpc.k8s.id

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = []
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = []
  }

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = []
  }

  ingress {
    description      = "Kubernetes API server"
    from_port        = 6443
    to_port          = 6443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = []
  }

  ingress {
    description      = "etcd server client API"
    from_port        = 2379
    to_port          = 2380
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = []
  }

  ingress {
    description      = "Kubelet API"
    from_port        = 10250
    to_port          = 10250
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = []
  }

  ingress {
    description      = "kube-scheduler"
    from_port        = 10259
    to_port          = 10259
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = []
  }

  ingress {
    description      = "kube-controller-manager"
    from_port        = 10257
    to_port          = 10257
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = []
  }

  egress {
    description      = ""
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = []

    prefix_list_ids = []
    security_groups = []
    self            = false
  }
}

# TLS private key
resource "tls_private_key" "master_0" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Key pair for SSH - master 0
resource "aws_key_pair" "master_0" {
  key_name   = "master-0"
  public_key = tls_private_key.master_0.public_key_openssh
}

# VM - master 0
resource "aws_instance" "master_0" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.medium"

  subnet_id              = aws_subnet.master.id
  vpc_security_group_ids = [aws_security_group.master.id]

  key_name = aws_key_pair.master_0.key_name

  user_data = "${file("../scripts/01_master_init.sh")}"
}

# Public IP
resource "aws_eip" "master_0" {
  instance = aws_instance.master_0.id
  domain   = "vpc"

  depends_on = [aws_internet_gateway.k8s]
}
