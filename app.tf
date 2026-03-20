data "ns_app_env" "this" {
  stack_id = data.ns_workspace.this.stack_id
  app_id   = data.ns_workspace.this.block_id
  env_id   = data.ns_workspace.this.env_id
}

locals {
  app_namespace = local.kubernetes_namespace
  app_name      = data.ns_workspace.this.block_name
  app_version   = coalesce(data.ns_app_env.this.version, "latest")
}

locals {
  app_metadata = tomap({
    service_account_id    = azurerm_user_assigned_identity.app.id
    service_account_email = azurerm_user_assigned_identity.app.client_id
    job_definition_namespace = local.kubernetes_namespace
    job_definition_name      = local.job_definition_name
  })
}
