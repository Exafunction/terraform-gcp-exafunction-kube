resource "kubernetes_secret" "exafunction_api_key" {
  metadata {
    name = var.exafunction_api_key_secret_name
  }
  data = {
    api_key = var.exafunction_api_key
  }
}

resource "kubernetes_secret" "cloud_sql_password" {
  count = var.module_repository_backend == "local" ? 0 : 1
  metadata {
    name = var.cloud_sql_password_secret_name
  }
  data = {
    postgres_password = var.cloud_sql_password
  }
}

resource "kubernetes_secret" "gcs_access" {
  count = var.module_repository_backend == "local" ? 0 : 1
  metadata {
    name = var.gcs_credentials_secret_name
  }
  binary_data = {
    "gcp-credentials.json" = var.gcs_credentials_json
  }
}

resource "kubernetes_namespace" "prometheus" {
  metadata {
    name = "prometheus"
  }
}

resource "kubernetes_secret" "prom_remote_write_basic_auth" {
  depends_on = [
    kubernetes_namespace.prometheus,
  ]

  count = var.enable_prom_remote_write ? 1 : 0
  metadata {
    name      = var.prom_remote_write_basic_auth_secret_name
    namespace = "prometheus"
  }
  data = {
    user     = var.prom_remote_write_username
    password = var.prom_remote_write_password
  }
}
