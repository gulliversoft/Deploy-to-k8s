output "local_repo" { value = artifactory_local_maven_repository.local.key }
output "virtual_repo" { value = artifactory_virtual_maven_repository.virtual.key }
output "oidc_issuer_url" { value = var.oidc_issuer_url }
output "oidc_token_endpoint" { value = "${var.oidc_issuer_url}/protocol/openid-connect/token" }
