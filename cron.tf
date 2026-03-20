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

              dynamic "env" {
                for_each = local.all_env_vars

                content {
                  name  = env.key
                  value = env.value
                }
              }

              dynamic "env" {
                for_each = toset(local.all_secret_keys)

                content {
                  name = env.value
                  value_from {
                    secret_key_ref {
                      name = "${local.resource_name}-akv-secrets"
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
