resource "azurerm_user_assigned_identity" "app" {
  name                = local.resource_name
  location            = var.location
  resource_group_name = local.resource_group_name
  tags                = local.tags
}

resource "kubernetes_service_account_v1" "app" {
  metadata {
    namespace = local.app_namespace
    name      = local.app_name
    labels    = local.k8s_component_labels

    annotations = {
      "azure.workload.identity/client-id" = azurerm_user_assigned_identity.app.client_id
    }
  }

  automount_service_account_token = true
}

resource "azurerm_federated_identity_credential" "app" {
  name                = local.resource_name
  resource_group_name = local.resource_group_name
  parent_id           = azurerm_user_assigned_identity.app.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = data.azurerm_kubernetes_cluster.this.oidc_issuer_url
  subject             = "system:serviceaccount:${local.app_namespace}:${local.app_name}"
}
