locals {
  cron_jobs = {
    for cj in local.capabilities.cron_jobs : "${cj.cap_tf_id}-${cj.name}" => {
      name                          = cj.name
      labels                        = lookup(cj, "labels", {})
      schedule                      = cj.schedule
      concurrency_policy            = lookup(cj, "concurrency_policy", null)
      suspend                       = lookup(cj, "suspend", false)
      failed_jobs_history_limit     = lookup(cj, "failed_jobs_history_limit", null)
      successful_jobs_history_limit = lookup(cj, "successful_jobs_history_limit", null)
      timezone                      = lookup(cj, "timezone", null)
      starting_deadline_seconds     = lookup(cj, "starting_deadline_seconds", null)
      ttl_seconds_after_finished    = lookup(cj, "ttl_seconds_after_finished", null)
    }
  }
}

resource "kubernetes_cron_job_v1" "this" {
  for_each = local.cron_jobs

  metadata {
    namespace = local.app_namespace
    name      = each.key
    labels    = each.value.labels
  }

  spec {
    schedule = each.value.schedule

    concurrency_policy = each.value.concurrency_policy

    suspend = each.value.suspend

    failed_jobs_history_limit     = each.value.failed_jobs_history_limit
    successful_jobs_history_limit = each.value.successful_jobs_history_limit

    timezone = each.value.timezone

    starting_deadline_seconds = each.value.starting_deadline_seconds

    job_template {
      metadata {
        namespace = local.kubernetes_namespace
        labels    = local.app_labels
      }
      spec {
        completions                = 1
        backoff_limit              = 0
        ttl_seconds_after_finished = each.value.ttl_seconds_after_finished

        template {
          metadata {
            labels = local.app_labels
          }
          spec {
            restart_policy       = "Never"
            service_account_name = kubernetes_service_account_v1.app.metadata[0].name

            container {
              name  = local.main_container_name
              image = "${local.repository_url}:${local.app_version}"
              args  = local.command

              // env vars with plain "value"
              dynamic "env" {
                for_each = data.ns_env_values.this.env_variables

                content {
                  name  = env.key
                  value = env.value
                }
              }

              // env vars with "{{ k8s.field(apiVersion, fieldPath) }}"
              dynamic "env" {
                for_each = data.ns_env_values.this.field_refs
                content {
                  name = env.key
                  value_from {
                    field_ref {
                      api_version = env.value.api_version
                      field_path  = env.value.field_path
                    }
                  }
                }
              }

              // env vars with "{{ k8s.configMap(key, name[, optional]) }}"
              dynamic "env" {
                for_each = data.ns_env_values.this.config_map_refs
                content {
                  name = env.key
                  value_from {
                    config_map_key_ref {
                      key      = env.value.key
                      name     = env.value.name
                      optional = env.value.optional
                    }
                  }
                }
              }

              // env vars with "{{ k8s.resourceField(resource[, container, divisor]) }}"
              dynamic "env" {
                for_each = data.ns_env_values.this.resource_field_refs
                content {
                  name = env.key
                  value_from {
                    resource_field_ref {
                      resource       = env.value.resource
                      container_name = env.value.container
                      divisor        = env.value.divisor
                    }
                  }
                }
              }

              // env vars with "{{ k8s.fileKey(key, path, volumeName) }}"
              // Requires K8s 1.34+ and EnvFiles feature gate
              dynamic "env" {
                for_each = data.ns_env_values.this.file_key_refs
                content {
                  name = env.key
                  value_from {
                    file_key_ref {
                      key         = env.value.key
                      path        = env.value.path
                      volume_name = env.value.volume_name
                    }
                  }
                }
              }

              // env vars with "{{ secret() }}"
              dynamic "env" {
                for_each = data.ns_env_layout.this.all_secret_keys

                content {
                  name = env.value
                  value_from {
                    secret_key_ref {
                      name = local.app_secret_store_name
                      key  = env.value
                    }
                  }
                }
              }

              dynamic "volume_mount" {
                for_each = local.pod_volume_mounts
                iterator = vm

                content {
                  name              = vm.value.name
                  mount_path        = vm.value.mountPath
                  sub_path          = vm.value.subPath
                  mount_propagation = vm.value.mountPropagation
                  read_only         = vm.value.readOnly
                  sub_path_expr     = vm.value.subPathExpr
                }
              }
            }

            dynamic "volume" {
              for_each = local.pod_volumes

              content {
                name = volume.value.name

                dynamic "empty_dir" {
                  for_each = volume.value.emptyDir == null ? [] : [1]
                  content {}
                }

                dynamic "persistent_volume_claim" {
                  for_each = volume.value.persistentVolumeClaim == null ? [] : [volume.value.persistentVolumeClaim]
                  iterator = pvc

                  content {
                    claim_name = pvc.value.claim_name
                    read_only  = try(pvc.value.readOnly, try(pvc.value.read_only, null))
                  }
                }

                dynamic "host_path" {
                  for_each = volume.value.hostPath == null ? [] : [volume.value.hostPath]
                  iterator = hp

                  content {
                    type = hp.value.type
                    path = hp.value.path
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
