#!/usr/bin/env bash
set -euo pipefail
K8S_CFG=/home/nonroot/.kube/config
CLUSTER_NAME=backstack

ensure_kubernetes() {
  if [ "$USE_KIND" = true ]; then
    if $(kind get clusters | grep -q ${CLUSTER_NAME}) 
    then
      echo KinD Cluster Exists
      kind export kubeconfig --name ${CLUSTER_NAME} --kubeconfig=${K8S_CFG}
    else
      echo Create KinD Cluster
      kind create cluster --name ${CLUSTER_NAME} --kubeconfig=${K8S_CFG} --config=/cnab/app/kind.cluster.config --wait=40s
    fi
    docker network connect kind ${HOSTNAME}
    KIND_DIND_IP=$(docker inspect -f "{{ .NetworkSettings.Networks.kind.IPAddress }}" ${CLUSTER_NAME}-control-plane)
    sed -i -e "s@server: .*@server: https://${KIND_DIND_IP}:6443@" /home/nonroot/.kube/config
  fi
}

configure_ingress() {
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/kind/deploy.yaml
  kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=90s 
}

configure_providers() {
  # configure provider-helm for crossplane
  waitfor default crd providerconfigs.helm.crossplane.io
  kubectl wait crd/providerconfigs.helm.crossplane.io --for=condition=Established --timeout=1m
  SA=$(kubectl -n crossplane-system get sa -o name | grep provider-helm | sed -e 's|serviceaccount\/|crossplane-system:|g')
  kubectl create clusterrolebinding provider-helm-admin-binding --clusterrole cluster-admin --serviceaccount="${SA}"
  kubectl create -f - <<- EOF
      apiVersion: helm.crossplane.io/v1beta1
      kind: ProviderConfig
      metadata:
        name: local
      spec:
        credentials:
          source: InjectedIdentity
EOF

  # configure provider-kubernetes for crossplane
  waitfor default crd providerconfigs.kubernetes.crossplane.io
  kubectl wait crd/providerconfigs.kubernetes.crossplane.io --for=condition=Established --timeout=1m
  SA=$(kubectl -n crossplane-system get sa -o name | grep provider-kubernetes | sed -e 's|serviceaccount\/|crossplane-system:|g')
  kubectl create clusterrolebinding provider-kubernetes-admin-binding --clusterrole cluster-admin --serviceaccount="${SA}"
  kubectl create -f - <<- EOF
      apiVersion: kubernetes.crossplane.io/v1alpha1
      kind: ProviderConfig
      metadata:
        name: local
      spec:
        credentials:
          source: InjectedIdentity
EOF

  # configure provider-azure for crossplane
  waitfor default crd providerconfigs.azure.upbound.io
  kubectl wait crd/providerconfigs.azure.upbound.io --for=condition=Established --timeout=1m
  kubectl create -f - <<- EOF
      apiVersion: azure.upbound.io/v1beta1
      kind: ProviderConfig
      metadata:
        name: default
      spec:
        credentials:
          source: Secret
          secretRef:
            namespace: crossplane-system
            name: azure-secret
            key: credentials    
EOF

  # configure provider-aws for crossplane
  waitfor default crd providerconfigs.aws.upbound.io
  kubectl wait crd/providerconfigs.aws.upbound.io --for=condition=Established --timeout=1m
  kubectl create -f - <<- EOF
      apiVersion: aws.upbound.io/v1beta1
      kind: ProviderConfig
      metadata:
        name: default
      spec:
        credentials:
          source: Secret
          secretRef:
            namespace: crossplane-system
            name: aws-secret
            key: credentials
EOF
}

upgrade() {
  echo World 2.0
}

uninstall() {
  if [ "$USE_KIND" = true ]; then
    kind delete cluster --name ${CLUSTER_NAME}
  fi
}

waitfor() {
  xtrace=$(set +o|grep xtrace); set +x
  local ns=${1?namespace is required}; shift
  local type=${1?type is required}; shift

  echo "Waiting for $type $*"
  # wait for resource to exist. See: https://github.com/kubernetes/kubernetes/issues/83242
  COUNT=0
  until kubectl -n "$ns" get "$type" "$@" -o=jsonpath='{.items[0].metadata.name}' >/dev/null 2>&1; do
    echo -e "\r\033[1A\033[0KWaiting for $type $* [${COUNT}s]"
    sleep 1
    ((COUNT++))
  done
  echo -e "\r\033[1A\033[0KWaiting for $type $* ...found"
  eval "$xtrace"
}

# Call the requested function and pass the arguments as-is
"$@"
