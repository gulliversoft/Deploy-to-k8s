resource "platform_oidc_configuration" "keycloak" {
  count         = var.enable_oidc ? 1 : 0
  name          = "keycloak-demo"
  issuer_url    = var.oidc_issuer_url
  provider_type = "generic"
  audience      = var.oidc_audience
  description   = "Demo Keycloak OIDC provider"
}

# Keycloak service-account tokens carry preferred_username=service-account-<client_id>
resource "platform_oidc_identity_mapping" "maven_ci" {
  count         = var.enable_oidc ? 1 : 0
  name          = "maven-ci"
  provider_name = platform_oidc_configuration.keycloak[0].name
  priority      = 1

  claims_json = jsonencode({
    azp = var.oidc_client_id
  })

  token_spec = {
    username   = "maven-ci"
    scope      = "applied-permissions/user"
    expires_in = 3600
  }
}

# Permissions for the OIDC token user
resource "platform_permission" "maven_ci" {
  count = var.enable_oidc ? 1 : 0
  name  = "maven-ci"

  artifact = {
    actions = {
      users = [{
        name        = "maven-ci"
        permissions = ["READ", "WRITE", "ANNOTATE"]
      }]
    }
    targets = [{
      name             = artifactory_local_maven_repository.local.key
      include_patterns = ["**"]
    }]
  }
}
