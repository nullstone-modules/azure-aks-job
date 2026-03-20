data "ns_connection" "cluster_namespace" {
  name     = "cluster-namespace"
  contract = "cluster-namespace/azure/k8s:aks"
}

locals {
  cluster_name           = data.ns_connection.cluster_namespace.outputs.cluster_name
  cluster_endpoint       = data.ns_connection.cluster_namespace.outputs.cluster_endpoint
  cluster_ca_certificate = data.ns_connection.cluster_namespace.outputs.cluster_ca_certificate
  kubernetes_namespace   = data.ns_connection.cluster_namespace.outputs.kubernetes_namespace
}

data "azurerm_kubernetes_cluster" "this" {
  name                = local.cluster_name
  resource_group_name = data.ns_connection.cluster_namespace.outputs.resource_group_name
}

provider "kubernetes" {
  host                   = local.cluster_endpoint
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.this.kube_config.0.client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.this.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(local.cluster_ca_certificate)
}
