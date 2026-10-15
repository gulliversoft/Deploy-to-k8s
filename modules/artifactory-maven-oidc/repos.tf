resource "artifactory_local_maven_repository" "local" {
  key              = var.local_repo_key
  handle_releases  = true
  handle_snapshots = true
}

resource "artifactory_virtual_maven_repository" "virtual" {
  key          = var.virtual_repo_key
  repositories = [artifactory_local_maven_repository.local.key]
}
