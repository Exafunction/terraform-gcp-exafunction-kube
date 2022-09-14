# Exafunction GCP Kubernetes Module

<img src="https://raw.githubusercontent.com/Exafunction/terraform-gcp-exafunction-kube/main/images/banner.png" alt="Exafunction x GCP x K8s" width="1280"/>

This repository provides a [Terraform](https://www.terraform.io/) module to set up the necessary [Kubernetes](https://kubernetes.io/) resources for an ExaDeploy system in a GCP [GKE cluster](https://cloud.google.com/kubernetes-engine/docs/concepts/kubernetes-engine-overview). This includes deploying:
* [Kubernetes secrets](https://kubernetes.io/docs/concepts/configuration/secret/) for the ExaDeploy system. This includes the Exafunction API key and optionally [GCS](https://cloud.google.com/storage/docs/introduction) access credentials and [CloudSQL](https://cloud.google.com/sql/docs/introduction) credentials needed for the persistent module repository backend.
* ExaDeploy [Helm](https://helm.sh/) chart responsible for bringing up ExaDeploy Kubernetes resources including the scheduler and module repository. See more details about the Helm chart [here](https://github.com/Exafunction/helm-charts/tree/main/charts/exadeploy).
* [Prometheus](https://prometheus.io/) Helm chart to create a Prometheus instance for ExaDeploy monitoring and a [Grafana](https://grafana.com/) instance for visualizing the metrics. See more details about the Helm chart [here](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack).
* [NVIDIA Driver Installer](https://github.com/GoogleCloudPlatform/container-engine-accelerators) to install the NVIDIA driver on the nodes in the cluster. See more details about running GPUs in GKE [here](https://cloud.google.com/kubernetes-engine/docs/how-to/gpus).

Because this module uses the [Kubernetes Terraform provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs) to create Kubernetes resources, it **should not** be used in the same Terraform root module that creates the GKE cluster these resources are deployed in. In simpler terms, GKE cluster creation and deployment of Kubernetes resources in that cluster should be managed with separate `terraform apply` operations. See this section of the official [Kubernetes provider docs](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs#stacking-with-managed-kubernetes-cluster-resources) or [this article](https://itnext.io/terraform-dont-use-kubernetes-provider-with-your-cluster-resource-d8ec5319d14a) describing the issue for more information.

## System Diagram

![System Diagram](https://raw.githubusercontent.com/Exafunction/terraform-gcp-exafunction-kube/main/images/system_diagram.png)

This diagram shows a typical setup of ExaDeploy in GKE (and adjacent GCP resources). It consists of:
* A [CloudSQL database](https://cloud.google.com/sql/docs/introduction) and [GCS bucket](https://cloud.google.com/storage/docs/introduction) used as a persistent backend for the ExaDeploy module repository. These are not strictly required as the module repository also supports a local backend (which is not persistent between module repository restarts) but is recommended in production. This Terraform module is not responsible for creating these resources but must be configured to use them by providing the appropriate access credentials and addressing information (see [Configuration - Module Repository Backend](#module-repository-backend)). To create these resources, see [Exafunction/terraform-gcp-exafunction-cloud/modules/module_repo_backend](https://github.com/Exafunction/terraform-gcp-exafunction-cloud/modules/module_repo_backend).
* An GKE cluster used to run the ExaDeploy system. This Terraform module is not responsible for creating the cluster. To create it, see [Exafunction/terraform-gcp-exafunction-cloud/modules/cluster](https://github.com/Exafunction/terraform-gcp-exafunction-cloud/modules/cluster).
* The ExaDeploy Kubernetes resources, specifically the module repository and scheduler (which is responsible for managing runners). This Terraform module is responsible for creating these resources.
* A [Prometheus](https://prometheus.io/) instance for monitoring the ExaDeploy system (along with a Grafana server used to visualize these metrics, not pictured). This Terraform module is responsible for creating these resource.

## Usage
```hcl
module "exafunction_kube" {
  # Set the module source and version to use this module.
  source = "Exafunction/exafunction-kube/gcp"
  version = "x.y.z"

  # Set the Exafunction API Key.
  exafunction_api_key = "12345678-1234-5678-1234-567812345678"

  # Set the ExaDeploy component images.
  scheduler_image         = gcr.io/exafunction/scheduler:prod_abcd1234_1234567812
  module_repository_image = gcr.io/exafunction/module_repository:prod_abcd1234_1234567812
  runner_image            = gcr.io/exafunction/runner@sha256:abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789

  # Set the module repository backend.
  module_repository_backend       = "local"

  # ...
}
```
See the configuration sections below as well as the [Inputs section](#inputs) and [variables.tf](https://github.com/Exafunction/terraform-gcp-exafunction-kube/blob/main/variables.tf) file for a full list of configuration options.

See [examples/setup_exadeploy](https://github.com/Exafunction/terraform-gcp-exafunction-kube/tree/main/examples/setup_exadeploy) for a working example of how to use this module.

## Cluster Configuration
While this module is not responsible for creating a [GKE cluster](https://cloud.google.com/kubernetes-engine/docs/concepts/kubernetes-engine-overview), it does require information about an existing cluster to deploy resources to, specifically the name of the cluster. For clusters created using [Exafunction/terraform-gcp-exafunction-cloud/modules/cluster](https://github.com/Exafunction/terraform-gcp-exafunction-cloud/modules/cluster), this information can be fetched using the `cluster_name` module output.

## ExaDeploy Helm Chart Configuration
This Terraform module installs the [ExaDeploy Helm chart](https://github.com/Exafunction/helm-charts/tree/main/charts/exadeploy) in the GKE cluster (version set by `exadeploy_helm_chart_version`). [Helm](https://helm.sh/) is a package manager for Kubernetes that allows for easy installation of applications in a Kubernetes cluster. Helm charts can be configured by passing in [values](https://helm.sh/docs/chart_template_guide/values_files/) when installing through a values yaml file or command line arguments.

The configuration of the ExaDeploy Helm chart in this Terraform module is split between required values which are managed through dedicated Terraform variables and optional values which can be supplied using the `exadeploy_helm_values_path` variable (see [Optional Configuration](#optional-configuration)). These are all detailed in the sections below.

As a note, "required" variables in this sense means they must be set in order to install the Helm chart at all. Other "optional" values may be necessary to support specific infratructure configurations, toggle features, or maximize performance.

### Exafunction API Key
The Exafunction API key is a unique key used to identify the ExaDeploy system to Exafunction. The API key itself should be provided by Exafunction.

To set, see the `exafunction_api_key` and `exafunction_api_key_secret_name` variables.

### ExaDeploy Component Images
The Exafunction component images are the Docker images used to run the ExaDeploy system. These should be provided by Exafunction.

To set, see the `scheduler_image`, `module_repository_image`, and `runner_image` variables.

### Module Repository Backend
The module repository can be configured to use either a local backend on disk or a remote backend backed by a [CloudSQL database](https://cloud.google.com/sql/docs/introduction) and [GCS bucket](https://cloud.google.com/storage/docs/introduction). The remote backend allows for persistence between module repository restarts and is recommended in production. For remote module backends created using [Exafunction/terraform-gcp-exafunction-cloud/modules/module_repo_backend](https://github.com/Exafunction/terraform-gcp-exafunction-cloud/modules/module_repo_backend), this information can be fetched from the module outputs.

To set, see the `module_repository_backend`, `cloud_sql_*`, and `gcs_*` variables. If `module_repository_backend` is `local` then the other variables do not need to be specified. If `module_repository_backend` is `remote` then the other variables must all be non-null.

### Optional Configuration
While the above sections cover all the required values for the ExaDeploy Helm chart configuration, there are many additional values that can be set to customize the deployment. These values are specified in a yaml file (in [Helm values file format](https://helm.sh/docs/chart_template_guide/values_files/)) and passed to the Helm chart installation through the optional `exadeploy_helm_values_path` variable.

To see all the available values to be set, see the [ExaDeploy Helm chart](https://github.com/Exafunction/helm-charts/tree/main/charts/exadeploy). Note that Helm chart values corresponding to the required values above should not be set through this method as they will overriden (multiple Helm values specifications are automatically merged).

## Prometheus Helm Chart Configuration
This Terraform module also installs the [Prometheus Helm chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) in the GKE cluster. This chart provides a Prometheus server and Grafana dashboard for monitoring the ExaDeploy system.

By default, the Grafana dashboard is made available on a private address within the VPC. The `enable_grafana_public_address` variable can be used to instead expose the Grafana dashboard on a public address for ease of access.

### Prometheus Remote Write
This module also by default enables Prometheus remote write functionality in order to send ExaDeploy system metrics to a remote Prometheus server owned by Exafunction. The remote receiving endpoint is secured by TLS and clients are authenticated by using basic auth with a username and password that Exafunction should provide. These metrics will help Exafunction better understand your usage of ExaDeploy, and more rapidly troubleshoot any issues which may occur.

To enable / disable this feature, see `enable_prom_remote_write`. When enabled (default), the `prom_remote_write_*` variables must be specified. In particular, `prom_remote_write_username` and `prom_remote_write_password` should be the username and password provided by Exafunction.

## Additional Resources

To learn more about Exafunction, visit the [Exafunction website](https://exafunction.com/).

For technical support or questions, check out our [community Slack](https://join.slack.com/t/exa-community/shared_invite/zt-1fx9dgcz5-aUg_UWW7zJYc_tYfw1TyNw).

For additional documentation about Exafunction including system concepts, setup guides, tutorials, API reference, and more, check out the [Exafunction documentation](https://docs.exafunction.com/).

For an equivalent repository used to set up ExaDeploy in a Kubernetes cluster on [Amazon Web Services (AWS)](https://aws.amazon.com/) instead of GCP, visit [`Exafunction/terraform-aws-exafunction-kube`](https://github.com/Exafunction/terraform-aws-exafunction-kube).

<!-- BEGIN_TF_DOCS -->
## Resources

| Name | Type |
|------|------|
| [helm_release.exadeploy](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.kube_prometheus_stack](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_manifest.nvidia_driver_installer](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_namespace.prometheus](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_secret.cloud_sql_password](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_secret.exafunction_api_key](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_secret.gcs_access](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_secret.prom_remote_write_basic_auth](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [http_http.nvidia_driver_installer_k8s_manifest](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cloud_sql_address"></a> [cloud\_sql\_address](#input\_cloud\_sql\_address) | Address of the CloudSQL database. | `string` | `null` | no |
| <a name="input_cloud_sql_password"></a> [cloud\_sql\_password](#input\_cloud\_sql\_password) | Password for CloudSQL instance. This will be stored in the CloudSQL password Kubernetes secret. | `string` | `null` | no |
| <a name="input_cloud_sql_password_secret_name"></a> [cloud\_sql\_password\_secret\_name](#input\_cloud\_sql\_password\_secret\_name) | CloudSQL password Kubernetes secret name. This secret will be created by this module. | `string` | `"cloud-sql-password"` | no |
| <a name="input_cloud_sql_port"></a> [cloud\_sql\_port](#input\_cloud\_sql\_port) | Port of the CloudSQL database. | `string` | `null` | no |
| <a name="input_cloud_sql_username"></a> [cloud\_sql\_username](#input\_cloud\_sql\_username) | Username for the CloudSQL database. | `string` | `null` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the Exafunction EKS cluster. | `string` | n/a | yes |
| <a name="input_enable_grafana_public_address"></a> [enable\_grafana\_public\_address](#input\_enable\_grafana\_public\_address) | Whether the Grafana service will be accessible via a public address. If false, the Grafana service will only be accessible via a private address within the VPC. | `bool` | `false` | no |
| <a name="input_enable_prom_remote_write"></a> [enable\_prom\_remote\_write](#input\_enable\_prom\_remote\_write) | Whether to enable remote writing Prometheus metrics to the Exafunction receiving endpoint. If true, all `prom_remote_*` variables must be set. | `bool` | `true` | no |
| <a name="input_exadeploy_helm_chart_version"></a> [exadeploy\_helm\_chart\_version](#input\_exadeploy\_helm\_chart\_version) | The version of the ExaDeploy Helm chart to use. | `string` | `"1.1.0"` | no |
| <a name="input_exadeploy_helm_values_path"></a> [exadeploy\_helm\_values\_path](#input\_exadeploy\_helm\_values\_path) | ExaDeploy Helm chart values yaml file path. | `string` | `null` | no |
| <a name="input_exafunction_api_key"></a> [exafunction\_api\_key](#input\_exafunction\_api\_key) | Exafunction API key used to identify the ExaDeploy system to Exafunction. | `string` | n/a | yes |
| <a name="input_exafunction_api_key_secret_name"></a> [exafunction\_api\_key\_secret\_name](#input\_exafunction\_api\_key\_secret\_name) | Exafunction API key Kubernetes secret name. This secret will be created by this module. | `string` | `"exafunction-api-key"` | no |
| <a name="input_gcs_bucket_name"></a> [gcs\_bucket\_name](#input\_gcs\_bucket\_name) | Name for GCS bucket. | `string` | `null` | no |
| <a name="input_gcs_credentials_json"></a> [gcs\_credentials\_json](#input\_gcs\_credentials\_json) | GCP credentials for the GCS service account. This will be stored in the GCS access GCP credentials Kubernetes secret. | `string` | `null` | no |
| <a name="input_gcs_credentials_secret_name"></a> [gcs\_credentials\_secret\_name](#input\_gcs\_credentials\_secret\_name) | GCS access GCP credentials Kubernetes secret name. This secret will be created by this module. | `string` | `"gcs-gcp-credentials"` | no |
| <a name="input_module_repository_backend"></a> [module\_repository\_backend](#input\_module\_repository\_backend) | The backend to use for the ExaDeploy module repository. One of [local, remote]. If remote, `gcs_*` and `cloud_sql_*` variables must be set. | `string` | `"local"` | no |
| <a name="input_module_repository_image"></a> [module\_repository\_image](#input\_module\_repository\_image) | Path to ExaDeploy module repository image. | `string` | n/a | yes |
| <a name="input_prom_remote_write_basic_auth_secret_name"></a> [prom\_remote\_write\_basic\_auth\_secret\_name](#input\_prom\_remote\_write\_basic\_auth\_secret\_name) | Prometheus remote write basic auth Kubernetes secret name. This secret will be created by this module. | `string` | `"prom-remote-write-basic-auth-secret"` | no |
| <a name="input_prom_remote_write_password"></a> [prom\_remote\_write\_password](#input\_prom\_remote\_write\_password) | Prometheus remote write basic auth password. This will be stored in the Prometheus remote write basic auth Kubernetes secret. | `string` | `null` | no |
| <a name="input_prom_remote_write_target_url"></a> [prom\_remote\_write\_target\_url](#input\_prom\_remote\_write\_target\_url) | Prometheus remote write target url. | `string` | `"https://prometheus.exafunction.com/api/v1/write"` | no |
| <a name="input_prom_remote_write_username"></a> [prom\_remote\_write\_username](#input\_prom\_remote\_write\_username) | Username (e.g. company name) for Prometheus remote write which will be used as a Prometheus label and basic auth username. This will be stored in the Prometheus remote write basic auth Kubernetes secret. | `string` | `null` | no |
| <a name="input_runner_image"></a> [runner\_image](#input\_runner\_image) | Path to ExaDeploy runner image. | `string` | n/a | yes |
| <a name="input_scheduler_image"></a> [scheduler\_image](#input\_scheduler\_image) | Path to ExaDeploy scheduler image. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_exadeploy_helm_release_metadata"></a> [exadeploy\_helm\_release\_metadata](#output\_exadeploy\_helm\_release\_metadata) | ExaDeploy Helm release attributes. |
| <a name="output_prometheus_helm_release_metadata"></a> [prometheus\_helm\_release\_metadata](#output\_prometheus\_helm\_release\_metadata) | Prometheus Helm release attributes. |
<!-- END_TF_DOCS -->
