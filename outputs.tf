output "exadeploy_helm_release_metadata" {
  description = "ExaDeploy Helm release attributes."
  value       = helm_release.exadeploy.metadata
}

output "prometheus_helm_release_metadata" {
  description = "Prometheus Helm release attributes."
  value       = helm_release.kube_prometheus_stack.metadata
}
