locals {
  additional_private_urls = []
  additional_public_urls  = []

  private_urls = concat([for cur in local.capabilities.private_urls : cur.url], local.additional_private_urls)
  public_urls  = concat([for cur in local.capabilities.public_urls : cur.url], local.additional_public_urls)
}
