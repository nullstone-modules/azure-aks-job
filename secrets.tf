resource "azurerm_key_vault" "app" {
  name                = substr(replace(local.resource_name, "/[^a-zA-Z0-9-]/", ""), 0, 24)
  location            = var.location
  resource_group_name = local.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
  tags                = local.tags

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_user_assigned_identity.app.principal_id

    secret_permissions = ["Get", "List"]
  }

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = ["Get", "List", "Set", "Delete", "Purge"]
  }
}

resource "azurerm_key_vault_secret" "app_secret" {
  for_each = data.ns_env_layout.this.managed_secret_keys

  name         = lower(replace("${local.resource_name}-${each.value}", "/[^a-zA-Z0-9-]/", "-"))
  value        = data.ns_env_values.this.secrets[each.value]
  key_vault_id = azurerm_key_vault.app.id
  tags         = local.tags
}

locals {
  // all_secrets is a map of name => secret name in Azure Key Vault
  // This is keyed from `ns_env_layout` so that the keys are known at plan time
  all_secrets = merge(
    { for key in data.ns_env_layout.this.unmanaged_secret_keys : key => data.ns_env_values.this.unmanaged_secret_refs[key] },
    { for key, secret in azurerm_key_vault_secret.app_secret : key => secret.name },
  )

  app_secret_store_name = "${local.resource_name}-akv-secrets"
}

resource "kubernetes_manifest" "akv_secret_store" {
  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "SecretStore"

    metadata = {
      namespace = local.app_namespace
      name      = local.app_secret_store_name
      labels    = local.k8s_component_labels
    }

    spec = {
      provider = {
        azurekv = {
          authType = "WorkloadIdentity"
          vaultUrl = azurerm_key_vault.app.vault_uri

          serviceAccountRef = {
            name = kubernetes_service_account_v1.app.metadata.0.name
          }
        }
      }
    }
  }
}

resource "kubernetes_manifest" "secrets_from_akv" {
  depends_on = [kubernetes_manifest.akv_secret_store]

  count = signum(length(data.ns_env_layout.this.all_secret_keys))

  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"

    metadata = {
      namespace = local.app_namespace
      name      = local.app_secret_store_name
      labels    = local.k8s_component_labels
    }

    spec = {
      secretStoreRef = {
        kind = "SecretStore"
        name = local.app_secret_store_name
      }
      target = {
        name = local.app_secret_store_name
      }
      data = [for key, value in local.all_secrets : {
        secretKey = key
        remoteRef = {
          key = value
        }
      }]
    }
  }
}

locals {
  secrets_checksum = sha256(jsonencode({ for key, secret in azurerm_key_vault_secret.app_secret : key => secret.version }))
}
