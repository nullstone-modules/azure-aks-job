locals {
  metrics_mappings = concat(local.base_metrics, local.capabilities.metrics)

  pod_name_regex  = "^${local.app_name}-[0-9a-f]{10}-.*$"
  query_namespace = local.app_namespace
  query_cluster   = local.cluster_name

  base_metrics = [
    {
      name = "app/cpu"
      type = "usage"
      unit = "cores"

      mappings = {
        cpu_reserved = {
          query = "KubePodInventory | where ClusterName == '${local.query_cluster}' and Namespace == '${local.query_namespace}' and Name matches regex '${local.pod_name_regex}' | summarize avg(PodRequestedCPU) by bin(TimeGenerated, 1m)"
        }
        cpu_average = {
          query = "Perf | where ObjectName == 'K8SContainer' and CounterName == 'cpuUsageNanoCores' and InstanceName matches regex '${local.pod_name_regex}' | summarize avg(CounterValue/1000000000) by bin(TimeGenerated, 1m)"
        }
      }
    },
    {
      name = "app/memory"
      type = "usage"
      unit = "MiB"

      mappings = {
        memory_reserved = {
          query = "KubePodInventory | where ClusterName == '${local.query_cluster}' and Namespace == '${local.query_namespace}' and Name matches regex '${local.pod_name_regex}' | summarize avg(PodRequestedMemoryBytes/1048576) by bin(TimeGenerated, 1m)"
        }
        memory_average = {
          query = "Perf | where ObjectName == 'K8SContainer' and CounterName == 'memoryWorkingSetBytes' and InstanceName matches regex '${local.pod_name_regex}' | summarize avg(CounterValue/1048576) by bin(TimeGenerated, 1m)"
        }
      }
    }
  ]
}

resource "azurerm_role_assignment" "deployer_monitoring_reader" {
  scope                = azurerm_resource_group.this.id
  role_definition_name = "Monitoring Reader"
  principal_id         = azurerm_user_assigned_identity.deployer.principal_id
}
