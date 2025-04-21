
resource "aws_lb" "this" {
  name = "some-alb"
  internal = false
  load_balancer_type = "application"
  security_groups = []
}
