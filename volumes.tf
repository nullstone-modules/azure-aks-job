locals {
  volumes = { for v in local.capabilities.volumes : v.name => v }

  volume_mounts = { for vm in local.capabilities.volume_mounts : vm.name => vm }
}
