locals {
  job_definition_name = "${local.resource_name}-job-definition"
  main_container_name = "main"
  command             = length(var.command) > 0 ? var.command : null
}

locals {
  pod_volumes = [
    for name, v in local.volumes : {
      name                  = name
      persistentVolumeClaim = v.persistent_volume_claim
      emptyDir              = v.empty_dir
      hostPath              = v.host_path
    }
  ]
  pod_volume_mounts = [for name, vm in local.volume_mounts : {
    name             = name
    mountPath        = vm.mount_path
    subPath          = vm.sub_path
    mountPropagation = vm.mount_propagation
    readOnly         = vm.read_only
    subPathExpr      = vm.sub_path_expr
  }]
  pod_env_vars = [
    for k, v in data.ns_env_values.this.env_variables : {
      name  = k
      value = v
    }
  ]
  // env vars with "{{ k8s.field(apiVersion, fieldPath) }}"
  pod_field_refs = [
    for k, v in data.ns_env_values.this.field_refs : {
      name = k
      valueFrom = {
        fieldRef = {
          apiVersion = v.api_version
          fieldPath  = v.field_path
        }
      }
    }
  ]
  // env vars with "{{ k8s.configMap(key, name[, optional]) }}"
  pod_config_map_refs = [
    for k, v in data.ns_env_values.this.config_map_refs : {
      name = k
      valueFrom = {
        configMapKeyRef = {
          key      = v.key
          name     = v.name
          optional = v.optional
        }
      }
    }
  ]
  // env vars with "{{ k8s.resourceField(resource[, container, divisor]) }}"
  pod_resource_field_refs = [
    for k, v in data.ns_env_values.this.resource_field_refs : {
      name = k
      valueFrom = {
        resourceFieldRef = {
          resource      = v.resource
          containerName = v.container
          divisor       = v.divisor
        }
      }
    }
  ]
  // env vars with "{{ k8s.fileKey(key, path, volumeName) }}"
  // Requires K8s 1.34+ and EnvFiles feature gate
  pod_file_key_refs = [
    for k, v in data.ns_env_values.this.file_key_refs : {
      name = k
      valueFrom = {
        fileKeyRef = {
          key        = v.key
          path       = v.path
          volumeName = v.volume_name
        }
      }
    }
  ]
  // env vars with "{{ secret() }}"
  pod_secrets = [
    for k in data.ns_env_layout.this.all_secret_keys : {
      name = k
      valueFrom = {
        secretKeyRef = {
          name = local.app_secret_store_name
          key  = k
        }
      }
    }
  ]

  job_definition = jsonencode({
    metadata = {
      namespace = local.kubernetes_namespace
      name      = ""
      labels    = local.app_labels
    }
    spec = {
      completions             = 1
      backoffLimit            = 0
      ttlSecondsAfterFinished = 24 * 60 * 60

      template = {
        metadata = {
          namespace = local.kubernetes_namespace
          labels    = local.app_labels
        }
        spec = {
          restartPolicy      = "Never"
          volumes            = local.pod_volumes
          serviceAccountName = kubernetes_service_account_v1.app.metadata[0].name

          containers = [
            {
              name  = local.main_container_name
              image = "${local.repository_url}:${local.app_version}"
              args  = local.command
              env = concat(
                local.pod_env_vars,
                local.pod_field_refs,
                local.pod_config_map_refs,
                local.pod_resource_field_refs,
                local.pod_file_key_refs,
                local.pod_secrets,
              )
              volumeMounts = local.pod_volume_mounts
            }
          ]
        }
      }
    }
  })
}

resource "kubernetes_config_map_v1" "job_definition" {
  metadata {
    namespace = local.kubernetes_namespace
    name      = local.job_definition_name
    labels    = local.app_labels
  }

  data = {
    template = local.job_definition
  }
}
