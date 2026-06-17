resource "aws_vpc" "client" {
  provider             = aws.eu-west-1
  cidr_block           = local.aws_config_env.vpc.client.cidr
  instance_tenancy     = "default"
  enable_dns_hostnames = "true"
  tags = merge(local.tags, {
    Name               = local.aws_config_env.vpc.client.name
    enable_dns_support = true
  })
}

resource "aws_flow_log" "client" {
  provider             = aws
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  log_destination_type = "cloud-watch-logs"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.client.id

  iam_role_arn             = aws_iam_role.flow_logs_role.arn
  max_aggregation_interval = 60
}





resource "aws_vpc" "inspect" {
  provider             = aws.eu-west-1
  cidr_block           = local.aws_config_env.vpc.inspect.cidr
  instance_tenancy     = "default"
  enable_dns_hostnames = "true"
  tags = merge(local.tags, {
    Name               = local.aws_config_env.vpc.inspect.name
    enable_dns_support = true
  })
}


data "aws_availability_zones" "zones" {
  provider = aws.eu-west-1
}

resource "aws_subnet" "subnet-1" {
  provider = aws.eu-west-1
  vpc_id   = aws_vpc.client.id

  cidr_block        = cidrsubnet(local.aws_config_env.vpc.client.cidr, 3, 0)
  availability_zone = data.aws_availability_zones.zones.names[0]
  tags = merge(local.tags, {
    Name = "subnet-1 - for client ec2 instance"
  })
}

resource "aws_subnet" "subnet-2" {
  provider = aws.eu-west-1
  vpc_id   = aws_vpc.client.id

  cidr_block        = cidrsubnet(local.aws_config_env.vpc.client.cidr, 3, 1)
  availability_zone = data.aws_availability_zones.zones.names[0]
  tags = merge(local.tags, {
    Name = "subnet-2 - for the GWLB endpoint"
  })
}

resource "aws_subnet" "subnet-3" {
  provider = aws.eu-west-1
  vpc_id   = aws_vpc.inspect.id

  cidr_block        = cidrsubnet(local.aws_config_env.vpc.inspect.cidr, 3, 0)
  availability_zone = data.aws_availability_zones.zones.names[0]
  tags = merge(local.tags, {
    Name = "subnet-3 - for inspect ec2 instance - and to host the GWLB"
  })
}

resource "aws_route_table" "client" {
  provider = aws.eu-west-1
  vpc_id   = aws_vpc.client.id

  tags = merge(local.tags, {
    Name = "Route table for client EC2 - the one to be inspected"
  })
}

resource "aws_route_table_association" "subnet-1" {
  provider       = aws.eu-west-1
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.client.id
}


resource "aws_route_table" "endpoint" {
  provider = aws.eu-west-1
  vpc_id   = aws_vpc.client.id

  tags = merge(local.tags, {
    Name = "Route table for GWLB endpoint within client VPC"
  })
}

resource "aws_route_table_association" "subnet-2" {
  provider       = aws.eu-west-1
  subnet_id      = aws_subnet.subnet-2.id
  route_table_id = aws_route_table.endpoint.id
}


resource "aws_route_table" "inspect" {
  provider = aws.eu-west-1
  vpc_id   = aws_vpc.inspect.id

  tags = merge(local.tags, {
    Name = "Route table for GWLB and inspect EC2 in inspect VPC"
  })
}

resource "aws_route_table_association" "subnet-3" {
  provider       = aws.eu-west-1
  subnet_id      = aws_subnet.subnet-3.id
  route_table_id = aws_route_table.inspect.id
}


resource "aws_internet_gateway" "inspect" {
  provider = aws.eu-west-1
  vpc_id   = aws_vpc.inspect.id
  tags = merge(local.tags, {
    Name = "client-igw"
  })
}

resource "aws_internet_gateway" "client" {
  provider = aws.eu-west-1
  vpc_id   = aws_vpc.client.id
  tags = merge(local.tags, {
    Name = "client-igw"
  })
}

resource "aws_route_table" "ingress" {
  provider = aws.eu-west-1
  vpc_id   = aws_vpc.client.id

  tags = merge(local.tags, {
    Name = "Route table for igress of internet traffic from client igw to be inspected by GWLB"
  })
}


resource "aws_route_table_association" "ingress" {
  provider       = aws.eu-west-1
  gateway_id     = aws_internet_gateway.client.id # ← Associate with IGW
  route_table_id = aws_route_table.ingress.id
}



### ROUTES

resource "aws_route" "inspect" {
  provider               = aws.eu-west-1
  route_table_id         = aws_route_table.inspect.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.inspect.id
}


resource "aws_route" "client" {
  provider               = aws.eu-west-1
  route_table_id         = aws_route_table.client.id
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = aws_vpc_endpoint.gwlb.id
}




resource "aws_route" "endpoint" {
  provider               = aws.eu-west-1
  route_table_id         = aws_route_table.endpoint.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.client.id
}


resource "aws_route" "ingress" {
  provider               = aws.eu-west-1
  route_table_id         = aws_route_table.ingress.id
  destination_cidr_block = aws_subnet.subnet-1.cidr_block
  vpc_endpoint_id        = aws_vpc_endpoint.gwlb.id
}
