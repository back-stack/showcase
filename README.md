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

## Installing with porter
You can also use [Porter][getporter] to perform the install

### Steps
1. Install porter [[link]][install-porter]
1. Create a credentials file
    ```yaml
    schemaType: CredentialSet
    schemaVersion: 1.0.1
    name: back-stack
    credentials:
      - name: github-token
        source:
          value: <personal access token>
      - name: vault-token
        source:
          value: root # this is the default for 'dev' mode
      - name: azure-credentials
        source:
          path: ~/azure-credentials.json
      - name: aws-credentials
        source:
          path: ~/.aws/credentials 
      - name: kubeconfig # if installing into an existing kubernetes cluster
        source:
          path: ~/.kube/config 
    ```
1. Create a parameters file
    ```yaml
    schemaType: ParameterSet
    schemaVersion: 1.0.1
    name: back-stack
    parameters:
      - name: 
    ```
1. Install the BACK stack
    ```shell
    porter install back-stack --reference ghcr.io/back-stack/showcase-bundle:v0.5.0 --credential-set back-stack --parameter-set back-stack
    ```



[getporter]: https://getporter.org
[install-porter]: https://getporter.org/docs/getting-started/install-porter/