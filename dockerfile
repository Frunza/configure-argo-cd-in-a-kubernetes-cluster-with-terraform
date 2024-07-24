FROM hashicorp/terraform:1.5.0

RUN apk update && apk add curl

ADD . /infrastructure
WORKDIR /infrastructure

# Define the environment variable
ARG CLUSTER_KUBECONFIG
# Write the kubeconfig content from the environment variable to the expected location
RUN echo "$CLUSTER_KUBECONFIG" > /infrastructure/config

CMD ["sh"]
