data "http" "nvidia_driver_installer_k8s_manifest" {
  url = "https://raw.githubusercontent.com/GoogleCloudPlatform/container-engine-accelerators/master/nvidia-driver-installer/cos/daemonset-preloaded.yaml"
}

resource "kubernetes_manifest" "nvidia_driver_installer" {
  manifest = yamldecode(data.http.nvidia_driver_installer_k8s_manifest.body)
  # TODO(nick): Use better way of applying driver installer and don't ignore `spec`.
  computed_fields = ["spec"]
}

resource "helm_release" "exadeploy" {
  depends_on = [
    kubernetes_manifest.nvidia_driver_installer,
    kubernetes_secret.exafunction_api_key,
  ]

  name       = "exadeploy"
  chart      = "exadeploy"
  repository = "https://exafunction.github.io/helm-charts"
  version    = var.exadeploy_helm_chart_version

  values = [
    var.exadeploy_helm_values_path == null ? "" : file(var.exadeploy_helm_values_path),
    yamlencode(
      {
        "exafunction" : {
          "apiKeySecret" : {
            "name" : var.exafunction_api_key_secret_name,
          },
        },
        "moduleRepository" : {
          "image" : var.module_repository_image,
          "nodeSelector" : {
            "role" = "module-repository",
          },
          "tolerations" : [{
            "key" : "dedicated",
            "operator" : "Equal",
            "value" : "module-repository",
            "effect" : "NoSchedule",
          }],
        },
        "scheduler" : {
          "image" : var.scheduler_image,
          "nodeSelector" : {
            "role" = "scheduler",
          },
          "tolerations" : [{
            "key" : "dedicated",
            "operator" : "Equal",
            "value" : "scheduler",
            "effect" : "NoSchedule",
          }],
        },
        "runner" : {
          "image" : var.runner_image,
          "nodeSelector" : {
            "role" = "runner",
          },
          "tolerations" : [{
            "key" : "dedicated",
            "operator" : "Equal",
            "value" : "runner",
            "effect" : "NoSchedule",
          }],
        },
      }
    ),
    var.module_repository_backend == "local" ? yamlencode(
      {
        "moduleRepository" : {
          "backend" : {
            "type" : "local",
          },
        }
      }
      ) : yamlencode({
        "moduleRepository" : {
          "backend" : {
            "type" : "remote",
            "remote" : {
              "postgres" : {
                "database" : "postgres",
                "host" : var.cloud_sql_address,
                "port" : var.cloud_sql_port,
                "user" : var.cloud_sql_username,
                "passwordSecret" : {
                  "name" : var.cloud_sql_password_secret_name,
                },
              }
              "dataBackend" : "gcs",
              "gcs" : {
                "bucket" : var.gcs_bucket_name,
                "gcpCredentialsSecret" : {
                  "name" : var.gcs_credentials_secret_name,
                },
              },
            },
          },
        },
    })
  ]
}

resource "helm_release" "kube_prometheus_stack" {
  name             = "prometheus"
  chart            = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  version          = "36.6.1"
  values           = [file("${path.module}/helm_prometheus.yaml")]
  namespace        = "prometheus"
  create_namespace = true
}
