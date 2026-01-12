# NLB
resource "aws_lb" "api" {
  name               = "one-api-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = aws_subnet.public[*].id

  enable_cross_zone_load_balancing = true
  enable_deletion_protection       = false

  tags = {
    Name = "one-api-nlb"
  }
}
