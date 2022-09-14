################################################################################
# EKS Cluster                                                                  #
################################################################################

variable "cluster_name" {
  description = "Name of the Exafunction EKS cluster."
  type        = string
}

################################################################################
# ExaDeploy Helm Chart                                                         #
################################################################################

variable "exadeploy_helm_chart_version" {
  description = "The version of the ExaDeploy Helm chart to use."
  type        = string
  default     = "1.1.0"
}

variable "exadeploy_helm_values_path" {
  description = "ExaDeploy Helm chart values yaml file path."
  type        = string
  default     = null
}

############################################################
# Exafunction API Key                                      #
############################################################

variable "exafunction_api_key_secret_name" {
  description = "Exafunction API key Kubernetes secret name. This secret will be created by this module."
  type        = string
  default     = "exafunction-api-key"
}

variable "exafunction_api_key" {
  description = "Exafunction API key used to identify the ExaDeploy system to Exafunction."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.exafunction_api_key))
    error_message = "Invalid Exafunction API key format."
  }
}

############################################################
# ExaDeploy Component Images                               #
############################################################

variable "scheduler_image" {
  description = "Path to ExaDeploy scheduler image."
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9.\\-_\\/@])+:([a-z0-9.-_])+$", var.scheduler_image))
    error_message = "Invalid ExaDeploy scheduler image path format."
  }
}

variable "module_repository_image" {
  description = "Path to ExaDeploy module repository image."
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9.\\-_\\/@])+:([a-z0-9.-_])+$", var.module_repository_image))
    error_message = "Invalid ExaDeploy module repository image path format."
  }
}

variable "runner_image" {
  description = "Path to ExaDeploy runner image."
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9.\\-_\\/@])+:([a-z0-9.-_])+$", var.runner_image))
    error_message = "Invalid ExaDeploy runner image path format."
  }
}

############################################################
# Module Repository Backend                                #
############################################################

variable "module_repository_backend" {
  description = "The backend to use for the ExaDeploy module repository. One of [local, remote]. If remote, `gcs_*` and `cloud_sql_*` variables must be set."
  type        = string
  default     = "local"

  validation {
    condition     = contains(["local", "remote"], var.module_repository_backend)
    error_message = "The \"module_repository_backend\" variable must be one of [local, remote]."
  }
}

#######################################
# GCS Bucket                          #
#######################################

variable "gcs_bucket_name" {
  description = "Name for GCS bucket."
  type        = string
  default     = null
}

variable "gcs_credentials_secret_name" {
  description = "GCS access GCP credentials Kubernetes secret name. This secret will be created by this module."
  type        = string
  default     = "gcs-gcp-credentials"
}

variable "gcs_credentials_json" {
  description = "GCP credentials for the GCS service account. This will be stored in the GCS access GCP credentials Kubernetes secret."
  type        = string
  sensitive   = true
  default     = null
}

#######################################
# CloudSQL Database                   #
#######################################

variable "cloud_sql_address" {
  description = "Address of the CloudSQL database."
  type        = string
  default     = null
}

variable "cloud_sql_port" {
  description = "Port of the CloudSQL database."
  type        = string
  default     = null
}

variable "cloud_sql_username" {
  description = "Username for the CloudSQL database."
  type        = string
  default     = null
}

variable "cloud_sql_password_secret_name" {
  description = "CloudSQL password Kubernetes secret name. This secret will be created by this module."
  type        = string
  default     = "cloud-sql-password"
}

variable "cloud_sql_password" {
  description = "Password for CloudSQL instance. This will be stored in the CloudSQL password Kubernetes secret."
  type        = string
  sensitive   = true
  default     = null
}

################################################################################
# Prometheus Helm Chart                                                        #
################################################################################

variable "enable_grafana_public_address" {
  description = "Whether the Grafana service will be accessible via a public address. If false, the Grafana service will only be accessible via a private address within the VPC."
  type        = bool
  default     = false
}

#######################################
# Remote Write                        #
#######################################

variable "enable_prom_remote_write" {
  description = "Whether to enable remote writing Prometheus metrics to the Exafunction receiving endpoint. If true, all `prom_remote_*` variables must be set."
  type        = bool
  default     = true
}

variable "prom_remote_write_target_url" {
  description = "Prometheus remote write target url."
  type        = string
  default     = "https://prometheus.exafunction.com/api/v1/write"
}

variable "prom_remote_write_basic_auth_secret_name" {
  description = "Prometheus remote write basic auth Kubernetes secret name. This secret will be created by this module."
  type        = string
  default     = "prom-remote-write-basic-auth-secret"
}

variable "prom_remote_write_username" {
  description = "Username (e.g. company name) for Prometheus remote write which will be used as a Prometheus label and basic auth username. This will be stored in the Prometheus remote write basic auth Kubernetes secret."
  type        = string
  default     = null
}

variable "prom_remote_write_password" {
  description = "Prometheus remote write basic auth password. This will be stored in the Prometheus remote write basic auth Kubernetes secret."
  type        = string
  sensitive   = true
  default     = null
}
