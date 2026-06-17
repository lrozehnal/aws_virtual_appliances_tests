resource "aws_lb" "gwlb" {
  provider           = aws.eu-west-1
  name               = "gwlb"
  load_balancer_type = "gateway"
  subnets            = [aws_subnet.subnet-3.id]
  tags = merge(local.tags, {
    Name = "gwlb-security"
  })
}


resource "aws_lb_target_group" "inspect" {
  provider    = aws.eu-west-1
  name        = "TG-inspect"
  port        = 6081
  protocol    = "GENEVE"
  vpc_id      = aws_vpc.inspect.id
  target_type = "instance"

  health_check {
    protocol            = "TCP"
    port                = 6081
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 10
  }
}



resource "aws_lb_target_group_attachment" "inspect" {
  provider         = aws.eu-west-1
  target_group_arn = aws_lb_target_group.inspect.arn
  target_id        = aws_instance.inspect.id
  port             = 6081
}

resource "aws_lb_listener" "gwlb" {
  provider          = aws.eu-west-1
  load_balancer_arn = aws_lb.gwlb.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.inspect.arn
  }
}

resource "aws_vpc_endpoint_service" "gwlb" {
  provider                   = aws.eu-west-1
  acceptance_required        = false
  gateway_load_balancer_arns = [aws_lb.gwlb.arn]

  tags = merge(local.tags, {
    Name = "gwlb-endpoint-service"
  })
}

resource "aws_vpc_endpoint" "gwlb" {
  provider          = aws.eu-west-1
  service_name      = aws_vpc_endpoint_service.gwlb.service_name
  vpc_id            = aws_vpc.client.id
  vpc_endpoint_type = "GatewayLoadBalancer"
  subnet_ids        = [aws_subnet.subnet-2.id]

  tags = merge(local.tags, {
    Name = "gwlb-endpoint"
  })
}