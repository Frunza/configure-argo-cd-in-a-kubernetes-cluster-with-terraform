#!/bin/sh

# Exit immediately if a simple command exits with a nonzero exit value
set -e

docker build --build-arg CLUSTER_KUBECONFIG="$CLUSTER_KUBECONFIG" -t terraformargocd .
docker-compose -f docker-compose.yml run --rm mainservice
