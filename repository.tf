resource "azurerm_container_registry" "this" {
  count = var.image_url == "" ? 1 : 0

  name                = substr(replace(local.resource_name, "/[^a-zA-Z0-9]/", ""), 0, 50)
  resource_group_name = local.resource_group_name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = false
  tags                = local.tags
}

locals {
  repository_url = var.image_url == "" ? "${azurerm_container_registry.this[0].login_server}/${local.app_name}" : var.image_url
}
