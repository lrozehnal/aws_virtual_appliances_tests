data "aws_ami" "ami" {
  provider    = aws.eu-west-1
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-6.*-arm64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_ssm_parameter" "ec2_private_key" {
  name            = "/ec2/default/private-key"
  with_decryption = true
}

# Read the public key (optional but useful)
data "aws_ssm_parameter" "ec2_public_key" {
  name            = "/ec2/default/public-key"
  with_decryption = false
}

resource "aws_key_pair" "key" {
  provider   = aws.eu-west-1
  key_name   = "ec2key-01" # You can keep this name stable
  public_key = data.aws_ssm_parameter.ec2_public_key.value

  tags = merge(local.tags, {
    Name = "EC2 key for lab"
  })
}


data "aws_route53_zone" "main" {
  provider = aws.eu-west-1
  name     = local.domain
}


# FortiGate PAYG / On-Demand AMI
data "aws_ami" "fortigate" {
  most_recent = true
  owners      = ["aws-marketplace"]

  filter {
    name   = "name"
    values = ["FortiGate-VM64-AWSONDEMAND*"]
  }
}


data "aws_network_interface" "gwlb_eni" {
  provider = aws.eu-west-1
  
  filter {
    name   = "attachment.instance-owner-id"
    values = ["amazon-aws"]   
  }


  filter {
    name   = "vpc-id"
    values = [aws_vpc.inspect.id]
  }

  filter {
    name   = "subnet-id"
    values = [aws_subnet.subnet-3.id]
  }
}



resource "aws_instance" "inspect" {
  ami           = data.aws_ami.fortigate.id
  instance_type = "t3.medium"
  key_name      = aws_key_pair.key.key_name
  subnet_id     = aws_subnet.subnet-3.id
  vpc_security_group_ids = [aws_security_group.inspect.id]

  associate_public_ip_address = false
  source_dest_check           = false

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = merge(local.tags, {
    Name = "fortigate-vm01"
  })


  user_data = templatefile("fortinet-userdata.tpl", {
    geneve_remote_ip = data.aws_network_interface.gwlb_eni.private_ip
  })

}


resource "aws_instance" "client" {
  ami           = data.aws_ami.ami.id
  instance_type = "t4g.micro"
  key_name      = aws_key_pair.key.key_name


  subnet_id                   = aws_subnet.subnet-1.id
  vpc_security_group_ids      = [aws_security_group.client.id]
  associate_public_ip_address = true
  user_data = <<-EOF
              #!/bin/bash
              sudo dnf install -y amazon-ssm-agent
              sudo systemctl enable --now amazon-ssm-agent
              EOF
  tags = merge(local.tags, {
    Name = "client"
  })
}



resource "aws_instance" "bastion" {
  ami           = data.aws_ami.ami.id
  instance_type = "t4g.micro"
  key_name      = aws_key_pair.key.key_name


  subnet_id                   = aws_subnet.subnet-2.id
  vpc_security_group_ids      = [aws_security_group.client.id]
  associate_public_ip_address = true
  user_data = <<-EOF
              #!/bin/bash
              sudo dnf install -y amazon-ssm-agent
              sudo systemctl enable --now amazon-ssm-agent
              EOF
  tags = merge(local.tags, {
    Name = "bastion"
  })
}



resource "aws_instance" "bastion2" {
  ami           = data.aws_ami.ami.id
  instance_type = "t4g.micro"
  key_name      = aws_key_pair.key.key_name


  subnet_id                   = aws_subnet.subnet-3.id
  vpc_security_group_ids      = [aws_security_group.inspect.id]
  associate_public_ip_address = true
  user_data = <<-EOF
              #!/bin/bash
              sudo dnf install -y amazon-ssm-agent
              sudo systemctl enable --now amazon-ssm-agent
              EOF
  tags = merge(local.tags, {
    Name = "bastion2"
  })
}



resource "aws_route53_record" "bastion" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "bastion.${local.domain}."
  type    = "A"
  ttl     = 300
  records = [aws_instance.bastion.public_ip]
}


resource "aws_route53_record" "bastion2" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "bastion2.${local.domain}."
  type    = "A"
  ttl     = 300
  records = [aws_instance.bastion2.public_ip]
}


/*
resource "aws_route53_record" "inspect" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "inspect.${local.domain}."
  type    = "A"
  ttl     = 300
  records = [aws_instance.inspect.public_ip]
}
*/


resource "aws_route53_record" "client" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "client.${local.domain}."
  type    = "A"
  ttl     = 300
  records = [aws_instance.client.public_ip]
}
