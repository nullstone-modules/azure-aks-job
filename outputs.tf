output "image_repo_url" {
  value       = local.repository_url
  description = "string ||| Service container image url."
}

output "log_provider" {
  value       = "aks"
  description = "string ||| The log provider used for this service."
}

output "metrics_provider" {
  value       = "azuremonitor"
  description = "string ||| "
}

output "metrics_reader" {
  value = {
    subscription_id = local.subscription_id
    client_id       = try(azurerm_user_assigned_identity.deployer.client_id, "")
  }

  description = "object({ subscription_id: string, client_id: string }) ||| An Azure identity with privilege to view metrics for this application."
}

output "metrics_mappings" {
  value       = local.metrics_mappings
  description = "string ||| A mapping of metric definitions used to render app metrics in the Nullstone UI."
}

output "app_name" {
  value       = local.app_name
  description = "string ||| "
}

output "service_name" {
  value       = ""
  description = "string ||| Always blank because we don't create a Kubernetes Service for tasks."
}

output "service_namespace" {
  value       = local.app_namespace
  description = "string ||| The kubernetes namespace where the app resides."
}

output "image_pusher" {
  value = {
    subscription_id = local.subscription_id
    client_id       = try(azurerm_user_assigned_identity.image_pusher.client_id, "")
  }

  description = "object({ subscription_id: string, client_id: string }) ||| An Azure identity that is allowed to push images."
}

output "deployer" {
  value = {
    subscription_id = local.subscription_id
    client_id       = try(azurerm_user_assigned_identity.deployer.client_id, "")
  }

  description = "object({ subscription_id: string, client_id: string }) ||| An Azure identity with explicit privilege to deploy this AKS job to its cluster."
}

output "main_container_name" {
  value       = local.main_container_name
  description = "string ||| The name of the container definition for the primary container"
}

output "job_definition_name" {
  value       = local.job_definition_name
  description = "string ||| The name of the Kubernetes ConfigMap containing the Job template"
}

output "private_urls" {
  value       = local.private_urls
  description = "list(string) ||| A list of URLs only accessible inside the network"
}

output "public_urls" {
  value       = local.public_urls
  description = "list(string) ||| A list of URLs accessible to the public"
}
