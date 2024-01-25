# See here for image contents: https://github.com/microsoft/vscode-dev-containers/tree/v0.245.2/containers/ubuntu/.devcontainer/base.Dockerfile
FROM mcr.microsoft.com/vscode/devcontainers/base:0-ubuntu-22.04

# Select desired TAG from https://github.com/argoproj/argo-cd/releases
ENV ARGOCD_VERSION=v2.9.3
RUN curl -sSL -o /usr/local/bin/argocd "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64" \
    && chmod +x /usr/local/bin/argocd

# Same K8s version that kind creates.
ENV KUBECTL_VERSION=v1.27.3
RUN curl -Lo /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
    && chmod +x /usr/local/bin/kubectl

# https://github.com/helm/helm/releases
ENV HELM_VERSION=v3.13.2
RUN curl -Lo /tmp/helm.tar.gz https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz \
    && tar -xvf /tmp/helm.tar.gz -C /tmp \
    && mv /tmp/linux-amd64/helm /usr/local/bin/helm \
    && chmod +x /usr/local/bin/helm

# https://releases.crossplane.io/stable/
ENV CROSSPLANE_VERSION=v1.14.4
RUN curl -Lo /usr/local/bin/crossplane "https://releases.crossplane.io/stable/${CROSSPLANE_VERSION}/bin/linux_amd64/crank" \
    && chmod +x /usr/local/bin/crossplane

# Used for Backstage development.
ENV NODE_MAJOR=18
RUN apt-get update \
    && apt-get install -y ca-certificates curl gnupg \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y nodejs \
    && npm install --global yarn

# https://github.com/kubernetes-sigs/kustomize/releases
ENV KUSTOMIZE_VERSION=v5.3.0
RUN curl -Lo /tmp/kustomize.tar.gz https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2F${KUSTOMIZE_VERSION}/kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz \
    && tar -xvf /tmp/kustomize.tar.gz -C /tmp \
    && mv /tmp/kustomize /usr/local/bin/kustomize \
    && chmod +x /usr/local/bin/kustomize

ENV YQ_VERSION=v4.40.5
RUN wget https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64.tar.gz -O - | tar xz \
    && mv yq_linux_amd64 /usr/bin/yq

RUN apt-get clean -y && rm -rf /var/lib/apt/lists/*
RUN mkdir /usr/local/etc/bash_completion.d

USER vscode

ENV PORTER_VERSION="v1.0.14"
RUN curl -L https://cdn.porter.sh/$PORTER_VERSION/install-linux.sh | bash
RUN echo 'PATH="$HOME/.porter:$PATH"' >> ~/.profile \
    && porter completion bash | sudo tee /usr/local/etc/bash_completion.d/porter

RUN echo alias k=kubectl >> ~/.bashrc \
    && mkdir ~/.kube
