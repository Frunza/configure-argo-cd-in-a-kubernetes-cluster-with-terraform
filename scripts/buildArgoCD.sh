#!/bin/sh

# Exit immediately if a simple command exits with a nonzero exit value
set -e


ARGOCD_VERSION="v2.8.4"

# Generate the yaml file for argocd
curl -o "./terraform/resources/k8s/argocd/argocd.${ARGOCD_VERSION}.yaml" "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

# Define the file path
INPUT_FILE="terraform/terraform.tfvars"

# Define the text to be replaced
SEARCH_TEXT="ARGOCD_VERSION"

# Use sed to perform the replacement
sed -i.bak "s/$SEARCH_TEXT/$ARGOCD_VERSION/g" $INPUT_FILE
