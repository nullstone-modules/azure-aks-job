variable "env_vars" {
  type        = map(string)
  default     = {}
  description = <<EOF
The environment variables to inject into the job.
These are typically used to configure a job per environment.
It is dangerous to put sensitive information in this variable because they are not protected and could be unintentionally exposed.
EOF
}

variable "secrets" {
  type        = map(string)
  default     = {}
  sensitive   = true
  description = <<EOF
The sensitive environment variables to inject into the job.
These are typically used to configure a job per environment.
EOF
}

locals {
  cap_env_vars = {
    for item in local.capabilities.env : "${local.cap_env_prefixes[item.cap_tf_id]}${item.name}" => item.value
  }
  cap_secrets = {
    for item in local.capabilities.secrets : "${local.cap_env_prefixes[item.cap_tf_id]}${item.name}" => sensitive(item.value)
  }

  standard_env_vars = tomap({
    NULLSTONE_STACK         = data.ns_workspace.this.stack_name
    NULLSTONE_APP           = data.ns_workspace.this.block_name
    NULLSTONE_ENV           = data.ns_workspace.this.env_name
    NULLSTONE_VERSION       = data.ns_app_env.this.version
    NULLSTONE_COMMIT_SHA    = data.ns_app_env.this.commit_sha
  })
  azure_env_vars = tomap({
    AZURE_SUBSCRIPTION_ID = local.subscription_id
    AZURE_CLIENT_ID       = azurerm_user_assigned_identity.app.client_id
  })

  input_env_vars    = merge(local.standard_env_vars, local.azure_env_vars, local.cap_env_vars, var.env_vars)
  input_secrets     = merge(local.cap_secrets, var.secrets)
  input_secret_keys = nonsensitive(concat(keys(local.cap_secrets), keys(var.secrets)))
}

data "ns_env_variables" "this" {
  input_env_variables = local.input_env_vars
  input_secrets       = local.input_secrets
}

data "ns_env_variables" "existing" {
  input_env_variables = var.env_vars
  input_secrets       = {}
}

data "ns_secret_keys" "this" {
  input_env_variables = var.env_vars
  input_secret_keys   = local.input_secret_keys
}

locals {
  all_env_vars = data.ns_env_variables.this.env_variables

  unmanaged_secret_keys = toset([for key, value in data.ns_env_variables.existing.secret_refs : key])
  managed_secret_keys   = setsubtract(data.ns_secret_keys.this.secret_keys, local.unmanaged_secret_keys)
  all_secret_keys       = toset(concat(tolist(local.unmanaged_secret_keys), tolist(local.managed_secret_keys)))

  unmanaged_secrets     = data.ns_env_variables.existing.secret_refs
  managed_secrets       = { for key in local.managed_secret_keys : key => azurerm_key_vault_secret.app_secret[key].name }
  managed_secret_values = data.ns_env_variables.this.secrets
  all_secrets           = merge(local.unmanaged_secrets, local.managed_secrets)
}
