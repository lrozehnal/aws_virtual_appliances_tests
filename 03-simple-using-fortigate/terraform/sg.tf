resource "aws_security_group" "client" {
  provider = aws
  vpc_id   = aws_vpc.client.id
  tags = merge(local.tags, {
    Name = "client EC2 SG"
  })

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}



resource "aws_security_group" "inspect" {
  provider = aws
  vpc_id   = aws_vpc.inspect.id
  tags = merge(local.tags, {
    Name = "inspect EC2 SG"
  })

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


