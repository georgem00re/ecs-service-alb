
resource "aws_security_group" "this" {
  vpc_id = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = {
    for index, inbound_rule in var.inbound_rules :
    index => inbound_rule
  }

  security_group_id            = aws_security_group.this.id
  cidr_ipv4                    = each.value.cidr_ipv4
  referenced_security_group_id = each.value.security_group_id
  from_port                    = each.value.from_port
  ip_protocol                  = each.value.ip_protocol
  to_port                      = each.value.to_port
}

resource "aws_vpc_security_group_egress_rule" "this" {
  for_each = {
    for index, outbound_rule in var.outbound_rules :
    index => outbound_rule
  }

  security_group_id            = aws_security_group.this.id
  cidr_ipv4                    = each.value.cidr_ipv4
  referenced_security_group_id = each.value.security_group_id
  from_port                    = each.value.from_port
  ip_protocol                  = each.value.ip_protocol
  to_port                      = each.value.to_port
}
