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
  depends_on = [
    kubernetes_namespace.prometheus,
    kubernetes_secret.prom_remote_write_basic_auth,
  ]

  name       = "prometheus"
  chart      = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  version    = "39.11.0"
  namespace  = "prometheus"
  values = [
    var.enable_prom_remote_write ? yamlencode(
      {
        "prometheus" : {
          "prometheusSpec" : {
            "secrets" : [var.prom_remote_write_basic_auth_secret_name]
            "remoteWrite" : [
              {
                "url" : var.prom_remote_write_target_url
                "writeRelabelConfigs" : [
                  {
                    "sourceLabels" : ["__name__"]
                    "targetLabel" : "from_remote"
                    "regex" : "(.+)"
                    "replacement" : "true"
                  },
                  {
                    "sourceLabels" : ["__name__"]
                    "targetLabel" : "cluster_name"
                    "regex" : "(.+)"
                    "replacement" : var.cluster_name
                  },
                  {
                    "sourceLabels" : ["__name__"]
                    "targetLabel" : "api_key"
                    "regex" : "(.+)"
                    "replacement" : var.exafunction_api_key
                  },
                  {
                    "sourceLabels" : ["__name__"]
                    "targetLabel" : "org_name"
                    "regex" : "(.+)"
                    "replacement" : var.prom_remote_write_username
                  }
                ]
                "tlsConfig" : {
                  # Require the Certificate Authority issuing the receiving endpoint's
                  # certificate to be publicly trusted.
                  "insecureSkipVerify" : false
                }
                "basicAuth" : {
                  "username" : {
                    "key" : "user"
                    "name" : var.prom_remote_write_basic_auth_secret_name
                  }
                  "password" : {
                    "key" : "password"
                    "name" : var.prom_remote_write_basic_auth_secret_name
                  }
                }
              }
            ]
          }
        },
      }
    ) : "",
    yamlencode(
      {
        "grafana" : {
          "service" : {
            "annotations" : {
              "service.beta.kubernetes.io/aws-load-balancer-internal" : var.enable_grafana_public_address ? "true" : "false"
            }
          }
        }
    }),
    file("${path.module}/helm_prometheus.yaml")
  ]
}
