# The BACK Stack

Find out more [backstack.dev](https://backstack.dev)

Basic architecture of the stack:
![architecture diagram](./imgs/arch.svg)

Watch the KubeCon NA 2023 session: [Introducing the BACK Stack!](https://youtu.be/SMlR12uwMLs)

## Install the BACK Stack

In order to try out the BACK Stack locally you can follow these steps

### Prerequisites

For a local install, you need Docker and Kind pre-installed.

### Getting started

Fork and clone the `showcase` repository

```sh
git clone git@github.com:back-stack/showcase.git
```

#### Setup Variables

-  [Create a personal access token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-personal-access-token-classic)
-  Configure `./.env` with your personal access token, the repository url, the vault token, your [provider-azure credentials](https://marketplace.upbound.io/providers/upbound/provider-family-azure/v0.38.2/docs/configuration), and your [provider-aws credentials](https://marketplace.upbound.io/providers/upbound/provider-family-aws/v0.43.1/docs/configuration)

```sh
$ cat << EOF > .env
GITHUB_TOKEN=<personal access token>
REPOSITORY=https://github.com/<path to forked repo>
VAULT_TOKEN=root # this is the default for 'dev' mode
AZURE_CREDENTIALS='{"clientId": "xxx","clientSecret": "xxx","subscriptionId": "xxx","tenantId": "xxx","activeDirectoryEndpointUrl": "https://login.microsoftonline.com","resourceManagerEndpointUrl": "https://management.azure.com/","activeDirectoryGraphResourceId": "https://graph.windows.net/","sqlManagementEndpointUrl": "https://management.core.windows.net:8443/","galleryEndpointUrl": "https://gallery.azure.com/","managementEndpointUrl": "https://management.core.windows.net/"}'
AWS_ACCESS_KEY_ID="xxx"
AWS_SECRET_ACCESS_KEY="xxx"
AWS_SESSION_TOKEN="xxx"
EOF
```

#### Run Installer

```sh
./local-install.sh
```

## Installing with Porter
You can also use [Porter][getporter] to perform the install
This Cloud Native Application Bundle supports installing the back stack on EKS, or locally using KinD

### Porter Bundle Info
Name: showcase-bundle
Description: The BACK stack showcase bundle
Version: 0.5.0+e1212b15
Porter Version: v1.0.15

Credentials:
---

| Name              | Description                                            | Required | 
|-------------------|--------------------------------------------------------|----------|
| aws-credentials   | Credentials to be used for Crossplane `provider-aws`   | true     |
| azure-credentials | Credentials to be used for Crossplane `provider-azure` | true     |
| github-token      | Github API token                                       | true     |
| kubeconfig        | kubeconfig to connect to non-local cluster             | false    |
| vault-token       | This should always be `root`                           | true     |

Parameters:
---

| Name           | Description                                                       | Type   | Default                                  | Required |
|----------------|-------------------------------------------------------------------|--------|------------------------------------------|----------|
| argocd-host    | DNS name for ArgoCD                                               | string | `argocd-7f000001.nip.io`                 | false    |
| backstage-host | DNS name for Backstage                                            | string | `backstage-7f000001.nip.io`              | false    |
| cluster-type   | Target kubernetes cluster type. Accepted values are `kind`, `eks` | string | `kind`                                   | false    |
| repository     | Gitops repository for cluster requests and catalog-info           | string | `https://github.com/back-stack/showcase` | true     |
| vault-host     | DNS name for Vault                                                | string | `vault-7f000001.nip.io`                  | false    |


This bundle uses the following tools: docker, exec, helm3, kubernetes.

To install this bundle run the following commands, passing `--param KEY=VALUE` for any parameters you want to customize:
```sh
porter credentials generate mycreds --reference ghcr.io/back-stack/showcase-bundle:latest
```
```sh
porter install --reference ghcr.io/back-stack/showcase-bundle:latest --credential-set mycreds --param repository=https://github.com/USER/REPO
```

### Installing Locally with KinD
#### Prerequisites
The porter bundle already includes KinD, so the only prerequisite is Docker.

1.  Install porter (see above)
1.  Generate the credentials config, leaving the `kubeconfig` empty (it will be ignored)
    ```
    porter credentials generate mycreds --reference ghcr.io/back-stack/showcase-bundle:latest
    ```
1.  Install the bundle; the default `cluster-type` and `*-host` parameters are configured for local deployment
    ```shell
    porter install back-stack --reference ghcr.io/back-stack/showcase-bundle:latest --credential-set mycreds --param repository=repository=https://github.com/USER/REPO
    ```

### Installing into EKS
#### Prerequisites
- Existing EKS cluster with [AWS Load Balancer Controller][alb-controller] add-on installed
- local `kubeconfig` file to connect to the cluster

1.  Install porter (see above)
1.  Generate the credentials config, specifying the path to the `kubeconfig` file
    ```
    porter credentials generate mycreds --reference ghcr.io/back-stack/showcase-bundle:latest
    ```
1.  Install the bundle; set `cluster-type` to `eks` and specify DNS names that you want to use to access the BACK stack services. This can either be done using `--param` flags, or by generating a parameter set
    ```shell
    # using --param
    porter install back-stack --reference ghcr.io/back-stack/showcase-bundle:latest --credential-set mycreds --param repository=repository=https://github.com/USER/REPO --param cluster-type=eks --param argocd-host=ARGOCD_DNS_NAME --param backstage-host=BACKSTAGE_DNS_NAME --param vault-host=VAULT_DNS_NAME
    
    # using parameter set
    porter parameters generate myparams --reference ghcr.io/back-stack/showcase-bundle:latest
    
    porter install back-stack --refrence ghcr.io/back-stack/showcase-bundle:latest --credential-set mycreds --parameter-set myparams
    ```
1.  After installation is complete, you need to ensure the DNS names specified for `argocd-host`, `backstage-host`, and `vault-host` all resolve to the ingress service created during installation. The endpoint for this can be found by checking the bundle outputs
    ```
    porter installations output show ingress -i back-stack
    ```
    This can be done by updating the DNS records directly if you control them, or by updating `/etc/hosts` or using a local DNS server such as `dnsmasq`.  

[getporter]: https://getporter.org
[install-porter]: https://getporter.org/docs/getting-started/install-porter/
[alb-controller]: https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html