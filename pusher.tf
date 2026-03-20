resource "azurerm_user_assigned_identity" "image_pusher" {
  name                = "pusher-${local.resource_name}"
  location            = var.location
  resource_group_name = local.resource_group_name
  tags                = local.tags
}

resource "azurerm_role_assignment" "image_pusher_acr_push" {
  count = var.image_url == "" ? 1 : 0

  scope                = azurerm_container_registry.this[0].id
  role_definition_name = "AcrPush"
  principal_id         = azurerm_user_assigned_identity.image_pusher.principal_id
}
