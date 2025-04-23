
resource "aws_network_acl" "this" {
  vpc_id = var.vpc_id
  subnet_ids = var.subnet_ids
}

resource "aws_network_acl_rule" "inbound" {
  for_each = var.inbound_rules
  network_acl_id = aws_network_acl.this.id
  rule_number = var.value.rule_number
  egress = false
  protocol = var.value.protocol
  rule_action = var.value.allow_or_deny
  cidr_block = var.value.cidr_block
  from_port = var.value.from_port
  to_port = var.value.to_port
}

resource "aws_network_acl_rule" "outbound" {
  for_each = var.inbound_rules
  network_acl_id = aws_network_acl.this.id
  rule_number = var.value.rule_number
  egress = true
  protocol = var.value.protocol
  rule_action = var.value.allow_or_deny
  cidr_block = var.value.cidr_block
  from_port = var.value.from_port
  to_port = var.value.to_port
}
