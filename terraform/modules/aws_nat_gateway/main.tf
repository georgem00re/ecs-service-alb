
resource "aws_eip" "this" {
  domain = "vpc"
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.this.id // Public NAT gateways require an elastic IP address.
  subnet_id = var.subnet_id
}
