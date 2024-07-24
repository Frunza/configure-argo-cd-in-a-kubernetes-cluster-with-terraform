# Configure Argo CD in a Kubernetes cluster with Terraform

## Scenario

You have a `kubernetes` cluster and you want to configure `Argo CD` in it. The fast and easy way is just to run a helm chart, but that is not the best way to do it, since others do not know what happened. What you want to do is somehow obtain the `yaml` files to set up `Argo CD` and apply them in the cluster in a programmatic way; `Terraform` can help you with that.

## Prerequisites

A Linux or MacOS machine for local development. If you are running Windows, you first need to set up the *Windows Subsystem for Linux (WSL)* environment.

You need `docker cli` and `docker-compose` on your machine for testing purposes, and/or on the machines that run your pipeline.
You can check both of these by running the following commands:
```sh
docker --version
docker-compose --version
```

To store your `Terraform` *state files* in `GitLab` you need the following:
`GitLab` access:
- GITLAB_USERNAME
- GITLAB_TOKEN
`Terraform` credentials:
- TF_HTTP_USERNAME
- TF_HTTP_PASSWORD

For `Terraform` to have access to your cluster, you need the `kubeconfig` file to access the cluster. You can provide its content via an environment variable:
- CLUSTER_KUBECONFIG: for convenience, you can add it directly to your profile. This can look like this, for example:
```sh
export CLUSTER_KUBECONFIG="apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tUZJQ0FURS0tLS0tCg==
    server: https://127.0.0.1:64571
  name: kind-kind-cluster
contexts:
- context:
    cluster: kind-kind-cluster
    user: kind-kind-cluster
  name: kind-kind-cluster
current-context: kind-kind-cluster
kind: Config
preferences: {}
users:
- name: kind-kind-cluster
  user:
    client-certificate-data: LS0tLS1CRUdJJUSUZJQ0FURS0tLS0tCg==
    client-key-data: LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLtFWS0tLS0tCg=="
```
, for a `kind` cluster.
Note the syntax: it needs double quotation marks at the beginning and the end of the ssh key value.
Note: if you use `GitLab`, the value of the environment variable must contain the content only, without the double quotation marks.

## Implementation

Let's take a first look at the required steps:
1) create a container that receives the whole repository as input, and inject it with all environment variables
2) create a `Terraform` project to add `Argo CD` to the cluster
3) add at least one `Argo CD` application; this will point to another git repository which probably does not exist, but we want to have a sample of how to do this since more `Argo CD` applications will be needed in time

Let's take a closer look at step 2.
To configure the `Terraform` project with cluster access, we need to provide it with a path to the `kubeconfig` file. An environment variable will not work for this. This means that during the creation of the container, we need to write the content of the CLUSTER_KUBECONFIG environment variable to a file and provide that path to the `Terraform` project.
To add `Argo CD` to the cluster via `Terraform` we need to provide the `yaml` files to set up `Argo CD`. We do not want the default latest version of `Argo CD`, but a specific one. It is a good practice to put the `Argo CD` version in the file name and let `Terraform` pick up that specific version. Since we probably want to add `Argo CD` to a specific namespace, we should create a `yaml` file for the namespace also.

Let's take a closer look at step 3.
When defining an `Argo CD` application, `Argo CD` needs access to the git repository. This means that some credentials have to be defined in the URL. So the first step is to add placeholders and replace them via a script with the values of the GITLAB_USERNAME and GITLAB_TOKEN environment variables.

Now that we know all the necessary considerations, let's start.

### Step 1

Since we later need to download the `Argo CD` `yaml` file, we need to add `curl` to the `dockerfile`:
```sh
RUN apk update && apk add curl
```

Let's copy the project to a location in the `dockerfile`:
```sh
ADD . /infrastructure
WORKDIR /infrastructure
```

Since `Terraform` needs a `kubeconfig` file, let's bake it in the `dockerfile`:
```sh
# Define the environment variable
ARG CLUSTER_KUBECONFIG
# Write the kubeconfig content from the environment variable to the expected location
RUN echo "$CLUSTER_KUBECONFIG" > /infrastructure/config
```

Do not forget to add the rest of the environment variables to `docker-compose`.
`docker-compose` should call the `Terraform` commands at the end, but just before that, we need to replace the placeholders from the `Argo CD` `yaml` file and application definition. We ca just add some scripts to run for this and fill them up later:
```sh
    command: [
      "sh scripts/buildArgoCD.sh && \
       sh scripts/updateArgoRepoCredentials.sh && \
       (cd terraform && terraform init && terraform validate && terraform apply -auto-approve)"
    ]
```
You can add more commands to execute as shown in the code snippet, or put them in a separate script and call that one script instead.

### Step 2

To allow `Terraform` to connect to the cluster, you need to properly configure the `kubectl` provider:
```sh
provider "kubectl" {
  load_config_file = true
  config_path      = "/infrastructure/config"
}
```

Now let's add `Argo CD` and its namespace to the cluster:
```sh
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
```

Let's also create the `Argo CD` `yaml` file:
 ```sh
ARGOCD_VERSION="v2.8.4"
curl -o "./terraform/resources/k8s/argocd/argocd.${ARGOCD_VERSION}.yaml" "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"
```

We also need to add the `yaml` files for each `Argo CD` application we want to manage. For `ingress-nginx` as an example:
```sh
data "kubectl_path_documents" "argoappsPath" {
    pattern = "resources/k8s/argoapps/*.yaml"
}

resource "kubectl_manifest" "argoappsYaml" {
    for_each  = toset(data.kubectl_path_documents.argoappsPath.documents)
    yaml_body = each.value
}
```

### Step 3

The `yaml` file for `ingress-nginx` could look like this:
```sh
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argo-infrastructure-nginx
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://GITLAB_USERNAME:GITLAB_TOKEN@git.my-company.com/my-repository.git
    targetRevision: HEAD
    path: ingress-nginx
    directory:
      recurse: true
  destination:
    server: https://kubernetes.default.svc
    namespace: ingress-nginx
    createNamespace: true
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Let's update the placeholders:
```sh
find "terraform/resources/k8s/argoapps" -type f -name "*.yaml" -exec sed -i.bak "s/GITLAB_TOKEN/$GITLAB_TOKEN/g; s/GITLAB_USERNAME/$GITLAB_USERNAME/g" {} \;
```

## Usage

Since everything runs inside a docker container, all you have to do is call the `update.sh` script.

You can also use a local cluster for testing purposes. For example, you can create a cluster with `kind`:
```sh
kind create cluster --name my-kind-cluster
```
The context for the new cluster will automatically be added to your `kubeconfig` file.

Direct `Argo CD` UI access is disabled. To access it, follow the steps below:

Establish a port-forward from `Argo CD` server to localhost:
```sh
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Retrieve the autogenerated password by running:
```sh
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

Navigate to **localhost:8080** in your browser. Login as **admin** user and the retrieved password.
