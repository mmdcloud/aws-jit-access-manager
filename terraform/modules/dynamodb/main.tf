locals {
  table_name = var.table_name != "" ? var.table_name : "${var.name_prefix}-JITAccessRequests"
}

resource "aws_dynamodb_table" "jit_requests" {
  name                        = local.table_name
  billing_mode                = var.billing_mode
  read_capacity               = var.billing_mode == "PROVISIONED" ? var.read_capacity : null
  write_capacity              = var.billing_mode == "PROVISIONED" ? var.write_capacity : null
  deletion_protection_enabled = var.deletion_protection_enabled

  hash_key = "RequestID"

  attribute {
    name = "RequestID"
    type = "S"
  }

  attribute {
    name = "Status"
    type = "S"
  }

  attribute {
    name = "ExpiryTime"
    type = "N"
  }

  attribute {
    name = "Username"
    type = "S"
  }

  attribute {
    name = "RequestedTime"
    type = "S"
  }

  # GSI 1: Query by Status ordered by ExpiryTime (used by approval, revocation sweeper, and dashboard)
  global_secondary_index {
    name            = "Status-ExpiryTime-Index"
    hash_key        = "Status"
    range_key       = "ExpiryTime"
    projection_type = "ALL"
    read_capacity   = var.billing_mode == "PROVISIONED" ? var.read_capacity : null
    write_capacity  = var.billing_mode == "PROVISIONED" ? var.write_capacity : null
  }

  # GSI 2: Query by Username ordered by RequestedTime (used for audit trail and user history)
  global_secondary_index {
    name            = "Username-RequestedTime-Index"
    hash_key        = "Username"
    range_key       = "RequestedTime"
    projection_type = "ALL"
    read_capacity   = var.billing_mode == "PROVISIONED" ? var.read_capacity : null
    write_capacity  = var.billing_mode == "PROVISIONED" ? var.write_capacity : null
  }

  point_in_time_recovery {
    enabled = var.point_in_time_recovery_enabled
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  ttl {
    attribute_name = "TTL"
    enabled        = true
  }

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  tags = merge(
    var.tags,
    {
      Name = local.table_name
    }
  )
}

