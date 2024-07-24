# Argo CD

data "kubectl_file_documents" "argocdNamespacePath" {
    content = file("resources/k8s/argocd/namespace.yaml")
}

data "kubectl_file_documents" "argocdInstallPath" {
    content = file("resources/k8s/argocd/argocd.${var.argocdVersion}.yaml")
}

resource "kubectl_manifest" "argocdNamespaceYaml" {
    for_each  = data.kubectl_file_documents.argocdNamespacePath.manifests
    yaml_body = each.value
}

resource "kubectl_manifest" "argocdInstallYaml" {
    for_each  = data.kubectl_file_documents.argocdInstallPath.manifests
    yaml_body = each.value
    override_namespace = "argocd"
    depends_on = [kubectl_manifest.argocdNamespaceYaml]
}

# Argo apps

data "kubectl_path_documents" "argoappsPath" {
    pattern = "resources/k8s/argoapps/*.yaml"
}

resource "kubectl_manifest" "argoappsYaml" {
    for_each  = toset(data.kubectl_path_documents.argoappsPath.documents)
    yaml_body = each.value
}
