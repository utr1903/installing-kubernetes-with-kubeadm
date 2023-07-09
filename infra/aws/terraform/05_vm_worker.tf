##################
### Worker VMs ###
##################

# Security group - Worker
resource "aws_security_group" "worker" {
  name        = "k8s_worker"
  description = "Allow inbound traffic for worker nodes"
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
    description      = "Kubelet API"
    from_port        = 10250
    to_port          = 10250
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = []
  }

  ingress {
    description      = "NodePort Services"
    from_port        = 30000
    to_port          = 32767
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
resource "tls_private_key" "worker_0" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Key pair for SSH - worker 0
resource "aws_key_pair" "worker_0" {
  key_name   = "worker-0"
  public_key = tls_private_key.worker_0.public_key_openssh
}

# VM - worker 0
resource "aws_instance" "worker_0" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.medium"

  subnet_id              = aws_subnet.worker.id
  vpc_security_group_ids = [aws_security_group.worker.id]

  key_name = aws_key_pair.worker_0.key_name

  user_data = file("../scripts/02_worker_init.sh")
}

# Public IP
resource "aws_eip" "worker_0" {
  instance = aws_instance.worker_0.id
  domain   = "vpc"

  depends_on = [aws_internet_gateway.k8s]
}
