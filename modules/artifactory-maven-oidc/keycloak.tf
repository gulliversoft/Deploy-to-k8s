locals {
  realm_name = "demo"

  realm = {
    realm   = local.realm_name
    enabled = true
    clients = [{
      clientId                  = var.oidc_client_id
      secret                    = var.oidc_client_secret
      enabled                   = true
      publicClient              = false
      serviceAccountsEnabled    = true
      standardFlowEnabled       = false
      directAccessGrantsEnabled = false
      protocolMappers = [{
        name           = "audience"
        protocol       = "openid-connect"
        protocolMapper = "oidc-audience-mapper"
        config = {
          "included.custom.audience" = var.oidc_audience
          "access.token.claim"       = "true"
          "id.token.claim"           = "true"
        }
      }]
    }]
  }
}

resource "kubernetes_namespace_v1" "keycloak" {
  count = var.deploy_keycloak ? 1 : 0
  metadata { name = var.keycloak_namespace }
}

resource "kubernetes_config_map_v1" "realm" {
  count = var.deploy_keycloak ? 1 : 0
  metadata {
    name      = "keycloak-realm"
    namespace = kubernetes_namespace_v1.keycloak[0].metadata[0].name
  }
  data = { "demo-realm.json" = jsonencode(local.realm) }
}

resource "kubernetes_deployment_v1" "keycloak" {
  count = var.deploy_keycloak ? 1 : 0
  metadata {
    name      = "keycloak"
    namespace = kubernetes_namespace_v1.keycloak[0].metadata[0].name
  }
  spec {
    replicas = 1
    selector { match_labels = { app = "keycloak" } }
    template {
      metadata { labels = { app = "keycloak" } }
      spec {
        container {
          name  = "keycloak"
          image = "quay.io/keycloak/keycloak:26.0"
          args  = ["start-dev", "--import-realm", "--hostname-strict=false", "--proxy-headers=xforwarded"]
          env {
            name  = "KC_BOOTSTRAP_ADMIN_USERNAME"
            value = "admin"
          }
          env {
            name  = "KC_BOOTSTRAP_ADMIN_PASSWORD"
            value = var.keycloak_admin_password
          }
          port { container_port = 8080 }
          volume_mount {
            name       = "realm"
            mount_path = "/opt/keycloak/data/import"
          }
          readiness_probe {
            tcp_socket { port = 8080 }
            initial_delay_seconds = 30
          }
        }
        volume {
          name = "realm"
          config_map { name = kubernetes_config_map_v1.realm[0].metadata[0].name }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "keycloak" {
  count = var.deploy_keycloak ? 1 : 0
  metadata {
    name      = "keycloak"
    namespace = kubernetes_namespace_v1.keycloak[0].metadata[0].name
  }
  spec {
    selector = { app = "keycloak" }
    type     = "NodePort"
    port {
      port        = 8080
      target_port = 8080
      node_port   = 30090
    }
  }
}
