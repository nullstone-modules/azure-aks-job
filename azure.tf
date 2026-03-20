provider "azurerm" {
  features {}
}

data "azurerm_subscription" "current" {}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "this" {
  name     = local.resource_name
  location = var.location
  tags     = local.tags
}

locals {
  resource_group_name = azurerm_resource_group.this.name
  subscription_id     = data.azurerm_subscription.current.subscription_id
}
