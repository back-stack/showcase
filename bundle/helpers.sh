#!/usr/bin/env bash
set -euo pipefail
K8S_CFG_INTERNAL=/home/nonroot/.kube/config
K8S_CFG_EXTERNAL=/home/nonroot/.kube/config-external
CLUSTER_NAME=backstack

validate_providers() {
  for provider in {crossplane-contrib-provider-{helm,kubernetes},upbound-provider-{family-{aws,azure},aws-{ec2,eks,iam},azure-{containerservice,network}}}; do
    kubectl wait providers.pkg.crossplane.io/${provider} --for='condition=healthy' --timeout=5m
  done
}

validate_configuration() {
  kubectl wait configuration/back-stack --for='condition=healthy' --timeout=10m
}

deploy_backstack_hub() {
  # deploy hub
  kubectl apply -f - <<-EOF
      apiVersion: backstack.dev/v1alpha1
      kind: Hub
      metadata:
        name: hub
      spec:
        parameters:
          clusterId: local
          repository: ${REPOSITORY}
          backstage:
            host: ${BACKSTAGE_HOST}
            image:
              registry: ghcr.io
              repository: back-stack/showcase-backstage
              tag: latest
              pullPolicy: IfNotPresent
          argocd:
            host: ${ARGOCD_HOST}
          vault:
            host: ${VAULT_HOST}
EOF
}

deploy_secrets() {
  ensure_namespace argocd
  kubectl apply -f - <<-EOF
    apiVersion: v1
    kind: Secret
    metadata:
      name: clusters
      namespace: argocd
      labels:
        argocd.argoproj.io/secret-type: repository
    stringData:
      type: git
      url: ${REPOSITORY}
      password: ${GITHUB_TOKEN}
      username: back-stack
EOF

  ensure_namespace backstage
  kubectl apply -f - <<-EOF
    apiVersion: v1
    kind: Secret
    metadata:
      name: backstage
      namespace: backstage
    stringData:
      GITHUB_TOKEN: ${GITHUB_TOKEN}
      VAULT_TOKEN: ${VAULT_TOKEN}
EOF

  ensure_namespace crossplane-system
  kubectl apply -f - <<-EOF
    apiVersion: v1
    kind: Secret
    metadata:
      name: azure-secret
      namespace: crossplane-system
    stringData:
      credentials: |
        ${AZURE_CREDENTIALS}
EOF

  kubectl apply -f - <<-EOF
    apiVersion: v1
    kind: Secret
    metadata:
      name: aws-secret
      namespace: crossplane-system
    stringData:
      credentials: |
        ${AWS_CREDENTIALS}
EOF
}

upgrade() {
  echo World 2.0
}

uninstall() {
  if [ "$CLUSTER_TYPE" = "kind" ]; then
    kind delete cluster --name ${CLUSTER_NAME}
  fi
}

ensure_namespace() {
  kubectl get namespaces -o name | grep -q $1 || kubectl create namespace $1
}

ensure_kubernetes() {
  if [ "$CLUSTER_TYPE" = "kind" ]; then
    if $(kind get clusters | grep -q ${CLUSTER_NAME}); then
      echo KinD Cluster Exists
      kind export kubeconfig --name ${CLUSTER_NAME} --kubeconfig=${K8S_CFG_INTERNAL}
      kind export kubeconfig --name ${CLUSTER_NAME} --kubeconfig=${K8S_CFG_EXTERNAL}
    else
      echo Create KinD Cluster
      kind create cluster --name ${CLUSTER_NAME} --kubeconfig=${K8S_CFG_INTERNAL} --config=/cnab/app/kind.cluster.config --wait=40s
      kind export kubeconfig --name ${CLUSTER_NAME} --kubeconfig=${K8S_CFG_EXTERNAL}
    fi
    docker network connect kind ${HOSTNAME}
    KIND_DIND_IP=$(docker inspect -f "{{ .NetworkSettings.Networks.kind.IPAddress }}" ${CLUSTER_NAME}-control-plane)
    sed -i -e "s@server: .*@server: https://${KIND_DIND_IP}:6443@" ${K8S_CFG_INTERNAL}
  fi
  kubectl get ns >/dev/null
}

# Call the requested function and pass the arguments as-is
"$@"
