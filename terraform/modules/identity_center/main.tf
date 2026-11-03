data "aws_ssoadmin_instances" "current" {}

locals {
  # Auto-discover or use user-supplied values
  sso_instance_arn  = var.sso_instance_arn != "" ? var.sso_instance_arn : try(tolist(data.aws_ssoadmin_instances.current.arns)[0], "")
  identity_store_id = var.identity_store_id != "" ? var.identity_store_id : try(tolist(data.aws_ssoadmin_instances.current.identity_store_ids)[0], "")
}

# ==============================================================================
# Optional Sample Permission Sets for JIT Access
# ==============================================================================
resource "aws_ssoadmin_permission_set" "jit_admin" {
  count            = var.create_sample_permission_sets && local.sso_instance_arn != "" ? 1 : 0
  name             = "JIT-ElevatedAdminAccess"
  description      = "Temporary Administrator Access granted via JIT workflow"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT1H" # 1 hour max session
  tags             = var.tags
}

resource "aws_ssoadmin_managed_policy_attachment" "jit_admin" {
  count              = var.create_sample_permission_sets && local.sso_instance_arn != "" ? 1 : 0
  instance_arn       = local.sso_instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  permission_set_arn = aws_ssoadmin_permission_set.jit_admin[0].arn
}

resource "aws_ssoadmin_permission_set" "jit_readonly" {
  count            = var.create_sample_permission_sets && local.sso_instance_arn != "" ? 1 : 0
  name             = "JIT-ElevatedReadOnlyAccess"
  description      = "Temporary ReadOnly Access granted via JIT workflow"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT4H" # 4 hours max session
  tags             = var.tags
}

resource "aws_ssoadmin_managed_policy_attachment" "jit_readonly" {
  count              = var.create_sample_permission_sets && local.sso_instance_arn != "" ? 1 : 0
  instance_arn       = local.sso_instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
  permission_set_arn = aws_ssoadmin_permission_set.jit_readonly[0].arn
}

