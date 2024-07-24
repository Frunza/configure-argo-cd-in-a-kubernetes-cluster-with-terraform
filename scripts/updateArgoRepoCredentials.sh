#!/bin/sh

# Exit immediately if a simple command exits with a nonzero exit value
set -e


# fill in the gitlab username and token in all argo apps
find "terraform/resources/k8s/argoapps" -type f -name "*.yaml" -exec sed -i.bak "s/GITLAB_TOKEN/$GITLAB_TOKEN/g; s/GITLAB_USERNAME/$GITLAB_USERNAME/g" {} \;
