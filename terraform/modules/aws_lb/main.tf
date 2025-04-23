
resource "aws_lb" "this" {
  internal           = false
  load_balancer_type = "application"
  subnets            = var.subnets
}
