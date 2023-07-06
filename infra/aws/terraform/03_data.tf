############
### Data ###
############

# AMI - Ubuntu 20.04
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "image-id"
    values = ["ami-0136ddddd07f0584f"]
  }
}
