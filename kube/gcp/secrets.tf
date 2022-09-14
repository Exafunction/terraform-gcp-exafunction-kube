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
