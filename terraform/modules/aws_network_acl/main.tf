
resource "aws_network_acl" "this" {
  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids
}

resource "aws_network_acl_rule" "inbound" {
  for_each = {
    for index, inbound_rule in var.inbound_rules :
    index => inbound_rule
  }

  network_acl_id = aws_network_acl.this.id
  rule_number    = each.value.rule_number
  egress         = false
  protocol       = each.value.protocol
  rule_action    = each.value.allow_or_deny
  cidr_block     = each.value.cidr_block
  from_port      = each.value.from_port
  to_port        = each.value.to_port
}

resource "aws_network_acl_rule" "outbound" {
  for_each = {
    for index, outbound_rule in var.outbound_rules :
    index => outbound_rule
  }

  network_acl_id = aws_network_acl.this.id
  rule_number    = each.value.rule_number
  egress         = true
  protocol       = each.value.protocol
  rule_action    = each.value.allow_or_deny
  cidr_block     = each.value.cidr_block
  from_port      = each.value.from_port
  to_port        = each.value.to_port
}
