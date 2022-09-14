provider "google" {
  project = var.project
  region  = var.region
}

data "google_client_config" "provider" {}

data "google_container_cluster" "cluster" {
  name     = var.cluster_name
  location = var.region
}

provider "kubernetes" {
  host = "https://${data.google_container_cluster.cluster.endpoint}"
  cluster_ca_certificate = base64decode(
    data.google_container_cluster.cluster.master_auth[0].cluster_ca_certificate,
  )
  token = data.google_client_config.provider.access_token
}

provider "helm" {
  kubernetes {
    host = "https://${data.google_container_cluster.cluster.endpoint}"
    cluster_ca_certificate = base64decode(
      data.google_container_cluster.cluster.master_auth[0].cluster_ca_certificate,
    )
    token = data.google_client_config.provider.access_token
  }
}
