#!/usr/bin/env bash
set -euo pipefail
K8S_CFG=/home/nonroot/.kube/config
CLUSTER_NAME=backstack

install() {
  ensure_kubernetes

  # configure ingress
  helm3 upgrade --install ingress-nginx --namespace ingress-nginx --create-namespace ingress-nginx/ingress-nginx --set 'controller.service.type=LoadBalancer' --set 'controller.service.annotations.service\.beta\.kubernetes\.io/aws-load-balancer-type=external' --set 'controller.service.annotations.service\.beta\.kubernetes\.io/aws-load-balancer-scheme=internet-facing' --set 'controller.service.annotations.service\.beta\.kubernetes\.io/aws-load-balancer-nlb-target-type=ip' --set 'controller.service.annotations.service\.beta\.kubernetes\.io/aws-load-balancer-healthcheck-protocol=http' --set 'controller.service.annotations.service\.beta\.kubernetes\.io/aws-load-balancer-healthcheck-path=/healthz' --set 'controller.service.annotations.service\.beta\.kubernetes\.io/aws-load-balancer-healthcheck-port=10254' --wait

  # install crossplane
  helm3 upgrade --install crossplane --namespace crossplane-system --create-namespace crossplane-stable/crossplane --set args='{--enable-external-secret-stores}' --wait

  # install vault ess plugin
  helm3 upgrade --install ess-plugin-vault oci://xpkg.upbound.io/crossplane-contrib/ess-plugin-vault --namespace crossplane-system --set-json podAnnotations='{"vault.hashicorp.com/agent-inject": "true", "vault.hashicorp.com/agent-inject-token": "true", "vault.hashicorp.com/role": "crossplane", "vault.hashicorp.com/agent-run-as-user": "65532"}'

  waitfor default crd configurations.pkg.crossplane.io

  # install back stack
  kubectl apply -f - <<-EOF
      apiVersion: pkg.crossplane.io/v1
      kind: Configuration
      metadata:
        name: back-stack
      spec:
        package: ghcr.io/opendev-ie/back-stack-configuration:v1.0.3
EOF


  # configure provider-helm for crossplane
  waitfor default crd providerconfigs.helm.crossplane.io
  kubectl wait crd/providerconfigs.helm.crossplane.io --for=condition=Established --timeout=1m
  SA=$(kubectl -n crossplane-system get sa -o name | grep provider-helm | sed -e 's|serviceaccount\/||g')
  kubectl apply -f - <<- EOF
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRoleBinding
      metadata:
        name: provider-helm-admin-binding
      roleRef:
        apiGroup: rbac.authorization.k8s.io
        kind: ClusterRole
        name: cluster-admin
      subjects:
      - kind: ServiceAccount
        name: ${SA}
        namespace: crossplane-system
EOF
  kubectl apply -f - <<- EOF
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
  SA=$(kubectl -n crossplane-system get sa -o name | grep provider-kubernetes | sed -e 's|serviceaccount\/||g')
  kubectl apply -f - <<- EOF
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRoleBinding
      metadata:
        name: provider-kubernetes-admin-binding
      roleRef:
        apiGroup: rbac.authorization.k8s.io
        kind: ClusterRole
        name: cluster-admin
      subjects:
      - kind: ServiceAccount
        name: ${SA}
        namespace: crossplane-system
EOF
  kubectl apply -f - <<- EOF
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
  kubectl apply -f - <<- EOF
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
  kubectl apply -f - <<- EOF
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

  # deploy hub
  waitfor default crd hubs.backstack.cncf.io
  kubectl wait crd/hubs.backstack.cncf.io --for=condition=Established --timeout=1m
  kubectl apply -f - <<-EOF
      apiVersion: backstack.cncf.io/v1alpha1
      kind: Hub
      metadata:
        name: hub
      spec: 
        parameters:
          clusterId: local
          repository: ${REPOSITORY}
          backstage:
            host: ${BACKSTAGE_HOST}
          argocd:
            host: ${ARGOCD_HOST}
          vault:
            host: ${VAULT_HOST}
EOF

  # deploy secrets
  waitfor default ns argocd
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

  waitfor default ns backstage
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


  waitfor argocd secret argocd-initial-admin-secret
  ARGO_INITIAL_PASSWORD=$(kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)

  # configure vault
  kubectl wait -n vault pod/vault-0 --for=condition=Ready --timeout=1m
  kubectl -n vault exec -i vault-0 -- vault auth enable kubernetes
  kubectl -n vault exec -i vault-0 -- sh -c 'vault write auth/kubernetes/config \
          token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
          kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
          kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt'
  kubectl -n vault exec -i vault-0 -- vault policy write crossplane - <<EOF
  path "secret/data/*" {
      capabilities = ["create", "read", "update", "delete"]
  }
  path "secret/metadata/*" {
      capabilities = ["create", "read", "update", "delete"]
  }
EOF
  kubectl -n vault exec -i vault-0 -- vault write auth/kubernetes/role/crossplane \
      bound_service_account_names="*" \
      bound_service_account_namespaces=crossplane-system \
      policies=crossplane \
      ttl=24h

  # restart ess pod
  kubectl get -n crossplane-system pods -o name | grep ess-plugin-vault | xargs kubectl delete -n crossplane-system 

  # ready to go!
  echo ""
  echo "
  Your BACK Stack is ready!

  Backstage: ${BACKSTAGE_HOST}
  ArgoCD: ${ARGOCD_HOST}
    username: admin
    password ${ARGO_INITIAL_PASSWORD}
  "
}

upgrade() {
  echo World 2.0
}

uninstall() {
  if [ "$USE_KIND" = true ]; then
    kind delete cluster --name ${CLUSTER_NAME}
  fi
}

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
  kubectl get ns
}

waitfor() {
  xtrace=$(set +o|grep xtrace); set +x
  local ns=${1?namespace is required}; shift
  local type=${1?type is required}; shift

  echo "Waiting for $type $*"
  # wait for resource to exist. See: https://github.com/kubernetes/kubernetes/issues/83242
  COUNT=0
  until kubectl -n "$ns" get "$type" "$*" -o=jsonpath='{.items[0].metadata.name}' >/dev/null 2>&1; do
    echo -e "\r\033[1A\033[0KWaiting for $type $* [${COUNT}s]"
    sleep 1
    ((COUNT++))
  done
  echo -e "\r\033[1A\033[0KWaiting for $type $* ...found"
  eval "$xtrace"
}

# Call the requested function and pass the arguments as-is
"$@"
