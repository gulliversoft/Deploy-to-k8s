

terraform {
  required_providers {
    artifactory = {
      source  = "jfrog/artifactory"
      version = "12.11.14"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    random = {
      source = "hashicorp/random"
    }
    helm = {
      source = "hashicorp/helm"
    }
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "minikube"
}

provider "helm" {
  kubernetes = {
    config_path    = "~/.kube/config"
    config_context = "minikube"
  }
}

############################
# VARIABLES (for flexibility)
############################

resource "random_string" "foo" {
  length  = 8
  upper   = false
  special = false
}

resource "random_id" "artifactory_master_key" {
  byte_length = 32
}

resource "random_id" "artifactory_join_key" {
  byte_length = 32
}

variable "namespace" {
  description = "The name of the Kubernetes namespace"
  type        = string
  default     = "k8s-ns-by-tf"
}

variable "deployment_name" {
  description = "The name of the Kubernetes deployment"
  type        = string
  default     = "terraform-example"
}

variable "app_label" {
  description = "App label for Kubernetes resources"
  type        = string
  default     = "MyExampleApp"
}

variable "replica_count" {
  description = "Number of deployment replicas"
  type        = number
  default     = 1
}

variable "headlamp_image" {
  description = "Headlamp image for the Kubernetes dashboard"
  type        = string
  default     = "ghcr.io/headlamp-k8s/headlamp:v0.45.0"
}

variable "artifactory_namespace" {
  description = "Namespace for the JFrog Artifactory Helm release"
  type        = string
  default     = "artifactory-oss"
}

variable "resource_requests_cpu" {
  description = "CPU requests for the container"
  type        = string
  default     = "250m"
}

variable "resource_requests_memory" {
  description = "Memory requests for the container"
  type        = string
  default     = "50Mi"
}

variable "resource_limits_cpu" {
  description = "CPU limits for the container"
  type        = string
  default     = "500m"
}

variable "resource_limits_memory" {
  description = "Memory limits for the container"
  type        = string
  default     = "512Mi"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owner annotation for resources"
  type        = string
  default     = "chefgs"
}


############################
# KUBERNETES OUTPUTS
############################

output "namespace_name" {
  description = "The name of the created Kubernetes namespace"
  value       = kubernetes_namespace_v1.example.metadata[0].name
}

output "namespace_uid" {
  description = "The UID of the created Kubernetes namespace"
  value       = kubernetes_namespace_v1.example.metadata[0].uid
}

# Removed namespace_status output as status is not directly accessible

output "deployment_name" {
  description = "The name of the created Kubernetes deployment"
  value       = kubernetes_deployment_v1.example.metadata[0].name
}

output "deployment_generation" {
  description = "The generation of the deployment"
  value       = kubernetes_deployment_v1.example.metadata[0].generation
}

output "deployment_replicas" {
  description = "The number of replicas in the deployment"
  value       = kubernetes_deployment_v1.example.spec[0].replicas
}

# Removed status-related outputs as they are not directly accessible in the provider

output "service_name" {
  description = "The name of the created Kubernetes service"
  value       = kubernetes_service_v1.example.metadata[0].name
}

output "service_cluster_ip" {
  description = "The cluster IP of the service"
  value       = kubernetes_service_v1.example.spec[0].cluster_ip
}

output "service_ports" {
  description = "The ports exposed by the service"
  value       = kubernetes_service_v1.example.spec[0].port[*].port
}

output "resource_quota_status" {
  description = "The status of the resource quota"
  value       = kubernetes_resource_quota_v1.example.spec[0].hard
}

output "kubernetes_connection_info" {
  description = "Information about the Kubernetes connection"
  value = {
    config_path    = "~/.kube/config"
    config_context = "minikube"
  }
  sensitive = false
}

output "service_endpoint" {
  description = "How to access the service (instructions)"
  value       = "To access the service within the cluster, use: ${kubernetes_service_v1.example.metadata[0].name}.${kubernetes_namespace_v1.example.metadata[0].name}.svc.cluster.local"
}

output "deployment_labels" {
  description = "Labels applied to the deployment"
  value       = kubernetes_deployment_v1.example.metadata[0].labels
}

output "pod_security_settings" {
  description = "Security settings applied to the pods"
  value = {
    run_as_non_root           = true
    read_only_root_filesystem = true
  }
}

output "artifactory_ui_node_port" {
  description = "NodePort for the Artifactory UI"
  value       = kubernetes_service_v1.artifactory_nodeport.spec[0].port[0].node_port
}

output "headlamp_service_account_token" {
  description = "Bearer token for the Headlamp ServiceAccount"
  value       = kubernetes_secret_v1.headlamp_token.data["token"]
  sensitive   = true
}

############################
# NAMESPACE
############################

resource "kubernetes_namespace_v1" "example" {
  metadata {
    name = var.namespace
    labels = {
      environment = var.environment
    }
    annotations = {
      owner = var.owner
    }
  }
}

########################################
# RESOURCE QUOTA & LIMIT RANGE (optional)
########################################

resource "kubernetes_resource_quota_v1" "example" {
  metadata {
    name      = "rq-example"
    namespace = kubernetes_namespace_v1.example.metadata[0].name
  }
  spec {
    hard = {
      "pods"            = 10
      "requests.cpu"    = "2"
      "requests.memory" = "2Gi"
      "limits.cpu"      = "4"
      "limits.memory"   = "4Gi"
    }
  }
}

resource "kubernetes_limit_range_v1" "example" {
  metadata {
    name      = "lr-example"
    namespace = kubernetes_namespace_v1.example.metadata[0].name
  }
  spec {
    limit {
      type = "Container"
      default = {
        cpu    = var.resource_limits_cpu
        memory = var.resource_limits_memory
      }
      default_request = {
        cpu    = var.resource_requests_cpu
        memory = var.resource_requests_memory
      }
    }
  }
}

resource "kubernetes_namespace_v1" "artifactory" {
  metadata {
    name = var.artifactory_namespace
  }
}

resource "kubernetes_secret_v1" "artifactory_mandatory_keys" {
  metadata {
    name      = "artifactory-mandatory-keys"
    namespace = kubernetes_namespace_v1.artifactory.metadata[0].name
  }

  type = "Opaque"

  data = {
    "master-key" = random_id.artifactory_master_key.hex
    "join-key"   = random_id.artifactory_join_key.hex
  }
}

############################
# JFROG ARTIFACTORY (HELM)
############################

resource "helm_release" "artifactory" {
  name             = "artifactory-oss"
  repository       = "https://charts.jfrog.io"
  chart            = "artifactory-oss"
  namespace        = var.artifactory_namespace
  create_namespace = false
  timeout          = 1800

  set = [
    {
      name  = "global.masterKeySecretName"
      value = kubernetes_secret_v1.artifactory_mandatory_keys.metadata[0].name
    },
    {
      name  = "global.joinKeySecretName"
      value = kubernetes_secret_v1.artifactory_mandatory_keys.metadata[0].name
    },
    {
      name  = "artifactory.postgresql.auth.password"
      value = "postgres_password"
    },
    {
      name  = "artifactory.nginx.enabled"
      value = "false"
    },
    {
      name  = "artifactory.ingress.enabled"
      value = "false"
    },
    {
      name  = "artifactory.persistence.enabled"
      value = "true"
    },
    {
      name  = "artifactory.persistence.size"
      value = "10Gi"
    }
  ]
}

resource "kubernetes_service_v1" "artifactory_nodeport" {
  metadata {
    name      = "artifactory-oss-nodeport"
    namespace = var.artifactory_namespace
  }

  spec {
    selector = {
      app       = "artifactory"
      component = "artifactory"
      release   = "artifactory-oss"
    }

    port {
      name        = "router"
      port        = 8082
      target_port = 8082
      node_port   = 30080
      protocol    = "TCP"
    }

    port {
      name        = "artifactory"
      port        = 8081
      target_port = 8081
      node_port   = 30082
      protocol    = "TCP"
    }

    type = "NodePort"
  }

  depends_on = [helm_release.artifactory]
}

resource "kubernetes_deployment_v1" "example" {
  metadata {
    name      = var.deployment_name
    namespace = kubernetes_namespace_v1.example.metadata[0].name
    labels = {
      app         = var.app_label
      environment = var.environment
    }
    annotations = {
      owner = var.owner
    }
  }

  spec {
    replicas = var.replica_count

    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_surge       = 0
        max_unavailable = 1
      }
    }

    selector {
      match_labels = {
        app = var.app_label
      }
    }

    template {
      metadata {
        labels = {
          app         = var.app_label
          environment = var.environment
        }
        annotations = {
          owner = var.owner
        }
      }

      spec {
        service_account_name = kubernetes_service_account_v1.headlamp.metadata[0].name

        container {
          name  = "headlamp"
          image = var.headlamp_image
          args  = ["-in-cluster", "-port", "8083"]

          port {
            container_port = 8083
          }

          resources {
            limits = {
              cpu    = var.resource_limits_cpu
              memory = var.resource_limits_memory
            }
            requests = {
              cpu    = var.resource_requests_cpu
              memory = var.resource_requests_memory
            }
          }

          startup_probe {
            http_get {
              path = "/"
              port = 8083
            }
            failure_threshold = 30
            period_seconds    = 10
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 8083
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 8083
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }
      }
    }
  }
}

resource "kubernetes_service_account_v1" "headlamp" {
  metadata {
    name      = "headlamp"
    namespace = kubernetes_namespace_v1.example.metadata[0].name
  }
}

resource "kubernetes_secret_v1" "headlamp_token" {
  metadata {
    name      = "headlamp-token"
    namespace = kubernetes_namespace_v1.example.metadata[0].name

    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account_v1.headlamp.metadata[0].name
    }
  }

  type = "kubernetes.io/service-account-token"
}

resource "kubernetes_cluster_role_binding_v1" "headlamp" {
  metadata {
    name = "headlamp"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.headlamp.metadata[0].name
    namespace = kubernetes_namespace_v1.example.metadata[0].name
  }
}

############################
# SERVICE (to expose pods)
############################

resource "kubernetes_service_v1" "example" {
  metadata {
    name      = "${var.deployment_name}-svc"
    namespace = kubernetes_namespace_v1.example.metadata[0].name
    labels = {
      app = var.app_label
    }
  }

  spec {
    selector = {
      app = var.app_label
    }
    port {
      name        = "headlamp"
      port        = 8081
      target_port = 8083
      node_port   = 30081
      protocol    = "TCP"
    }
    type = "NodePort"
  }
}