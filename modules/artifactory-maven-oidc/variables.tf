variable "local_repo_key" {
  type    = string
  default = "maven-local"
}

variable "virtual_repo_key" {
  type    = string
  default = "maven-virtual"
}

variable "enable_oidc" {
  description = "OIDC integration needs a JFrog edition that supports it (not available in OSS)"
  type        = bool
  default     = true
}

variable "oidc_issuer_url" {
  description = "Issuer URL as reachable by Artifactory (must match the 'iss' claim). Artifactory expects HTTPS."
  type        = string
}

variable "oidc_audience" {
  type    = string
  default = "jfrog-artifactory"
}

variable "oidc_client_id" {
  description = "Keycloak client / token subject allowed to deploy"
  type        = string
  default     = "maven-ci"
}

variable "oidc_client_secret" {
  type      = string
  sensitive = true
  default   = "change-me-demo-secret"
}

variable "deploy_keycloak" {
  description = "Deploy a demo Keycloak (dev mode) as OIDC provider"
  type        = bool
  default     = true
}

variable "keycloak_namespace" {
  type    = string
  default = "keycloak"
}

variable "keycloak_admin_password" {
  type      = string
  sensitive = true
  default   = "admin"
}
