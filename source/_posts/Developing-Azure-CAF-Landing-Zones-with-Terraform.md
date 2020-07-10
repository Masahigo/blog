---
title: Developing Azure CAF Landing Zones with Terraform
tags:
  - Cloud Adoption Framework
  - Terraform
  - VSCode
  - Azure DevOps
  - Azure CLI
  - Landing Zones
photos:
  - /images/photos/caf-rover.jpg
categories:
  - Azure
  - CI/CD
  - Docker
  - IaC
date: 2020-07-10 21:53:27
---




A kickstart to the development of Terraform based Landing Zones following Azure's Cloud Adoption Framework. 

<!-- more -->

## A short introduction

Within the past year or so Microsoft has put a lot of effort into documenting best practices and guidelines for customers embarking on their journey with Azure. This is called the _Microsoft Cloud Adoption Framework for Azure (CAF)_. Simultaneously, they've started to roll out some tools and concepts to make it easier to jump in. 

_Landing Zones_, on the other hand, is a concept that was introduced by AWS a few years ago. It's an abstract idea although AWS tried to implement and sell it as a ready-made solution, with poor success. I'm not the best person to describe them, but you can check [this excellent post blog](https://medium.com/polarsquad/anatomy-of-a-landing-zone-part-i-6b35e3668eb5) on the topic. Essentially they're just a way to layer the building blocks of your cloud infrastructure. The technology used for implementing the IaC for Landing Zones is entirely up to you.

I started to investigate the [Azure Cloud Adoption Framework landing zones for Terraform](https://github.com/Azure/caf-terraform-landingzones) for a customer case this spring. They were planning to use Azure DevOps as the CI/CD tool. I had to figure out a lot of things before I could concentrate on developing the actual Landing Zones so I figured to share my view on this.

## Getting started

I bet you a million bucks these are the first things you encounter

- A tool called _Rover_
- The concept of a _Launchpad_

So what are these? With Terraform, when you start to build the IaC you most likely need a remote state. Then it would be also nice to have a place to store some secrets. There's your [Launchpad](https://github.com/aztfmod/level0). And [Rover](https://github.com/aztfmod/rover) is a simple tool for deploying Terraform based landing zones, including the launchpad (level0). Both are provided by some MS folks for our convenience.

Since we're dealing with mainly IaC here it's not mandatory to use Rover of course. This is pure Terraform stuff. But this so-called bootstrapping of Terraform's remote state and managing few credentials is something you'd need to handle in any case, one way or another.

### Local development

I recommend starting to use Rover from the get-go. Microsoft has done a great job of wrapping the tool into a [Dev Container](https://code.visualstudio.com/docs/remote/containers). All you have to install in your local machine is Docker and VSCode with a couple of extensions. Using the Dev Container you have all the tools needed to start developing Terraform based Landing Zones.

{% blockquote %}
Check the [getting started guide](https://github.com/Azure/caf-terraform-landingzones/blob/master/documentation/getting_started/getting_started.md) for detailed instructions.
{% endblockquote %}

When you start Rover in VSCode you'll notice the Dev Container being initialized

{% asset_img vscode-starting-dev-container.jpg Dev Container initializing in VSCode %}

Once the Dev Container has loaded you can check few things from the terminal

```bash
[vscode@c34ec5f22ad1 caf] $ pwd
/tf/caf

[vscode@c34ec5f22ad1 caf] $ ls -la
total 68
drwxr-xr-x 9 vscode vscode 4096 Jul  8 06:37 .
drwxr-xr-x 1 root   root   4096 Jul  8 10:56 ..
-rw-r--r-- 1 vscode vscode 6450 Jul  3 11:42 CHANGELOG.md
-rw-r--r-- 1 vscode vscode  444 Jul  3 11:42 CODE_OF_CONDUCT.md
drwxr-xr-x 2 vscode vscode 4096 Jul  3 11:42 .devcontainer
drwxr-xr-x 6 vscode vscode 4096 Jul  3 11:42 documentation
drwxr-xr-x 3 vscode vscode 4096 Jul  3 11:42 environments
drwxr-xr-x 8 vscode vscode 4096 Jul  8 10:55 .git
drwxr-xr-x 4 vscode vscode 4096 Jul  3 11:42 .github
-rw-r--r-- 1 vscode vscode  148 Jul  3 11:42 .gitignore
drwxr-xr-x 9 vscode vscode 4096 Jul  3 11:42 landingzones
-rw-r--r-- 1 vscode vscode 1066 Jul  3 11:42 LICENSE
drwxr-xr-x 9 vscode vscode 4096 Jul  3 11:42 _pictures
-rw-r--r-- 1 vscode vscode 9858 Jul  3 11:42 README.md

[vscode@c34ec5f22ad1 caf] $ az account show
Please run 'az login' to setup account.
```

### A quick start directly from Rover

{% blockquote %}
I've created [a simple landing zone example](https://github.com/Masahigo/caf-terraform-landingzone-example) that we use as a reference here. It contains a simple Azure policy for requiring a specific tag for resource groups.
{% endblockquote %}

**Prerequisites**

- Azure subscription
- A User account with Global Administrator permissions
- Azure DevOps organization

**What we're going to do**

- Azure Repos to store our Terraform configs and pipeline definition
  * The referenced Git repository
- Interact with Azure DevOps (ADO) using the [Azure DevOps extension for Azure CLI](https://docs.microsoft.com/en-us/azure/devops/cli/?view=azure-devops)
  * It supports only Personal Access Tokens (PAT) as an authentication mechanism
  * _Creating the PAT is the only manual step - the rest is handled from the command line_
- Rover is used to deploying the reference landing zone
- Test and verify the landing zone is working

{% raw %}
<div style="width:100%;height:0;padding-bottom:75%;position:relative;"><iframe src="https://giphy.com/embed/3o7TKUM3IgJBX2as9O" width="100%" height="100%" style="position:absolute" frameBorder="0" class="giphy-embed" allowFullScreen></iframe></div><p><a href="https://giphy.com/gifs/seinfeld-kramer-lets-go-3o7TKUM3IgJBX2as9O">via GIPHY</a></p>
{% endraw %}

1. Create a [PAT](https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=azure-devops&tabs=preview-page#create-personal-access-tokens-to-authenticate-access) from Azure DevOps and grab the token

    **Agent Pools**: `Read`
    **Build**: `Read & Execute`
    **Code**: `Read write, & manage`
    **Project and Team**: `Read, write, & manage`
    **Release**: `Read, write, execute & manage`

    **Note: PAT has permissions to manage ADO Projects in this example!**

{% asset_img ado-creating-pat.png Creating PAT in Azure DevOps %}

2. Login to Azure CLI via device login

```bash
$ az login
```

3. Install ADO extension and login

```bash
$ az extension add --name azure-devops

# Login to Azure DevOps - providing the PAT token created previously (1. time)
$ az devops login
```

4) Create new ADO project, import the example git repo to ADO and then clone it to Rover container

```bash
# Create new folder in Rover container context
sudo mkdir /tf/caf-custom && sudo chown -R $(whoami) /tf/caf-custom

# Prepare your environment
$ AZURE_DEVOPS_ORGANIZATION='<your-azure-devops-organization>'
$ AZURE_DEVOPS_ACCOUNT='https://dev.azure.com/<your-azure-devops-organization>/'
$ AZURE_DEVOPS_PROJECT='testing-caf-landingzones'

$ az devops configure --defaults organization="$AZURE_DEVOPS_ACCOUNT" project="$AZURE_DEVOPS_PROJECT"

# Create new Project to ADO
$ az devops project create --name "$AZURE_DEVOPS_PROJECT"

# Import this repo to ADO Project's default git repo
$ az repos import create --git-url https://github.com/Masahigo/caf-terraform-landingzone-example.git --repository "$AZURE_DEVOPS_PROJECT"

# Paste PAT (2. time)
$ AZURE_DEVOPS_PAT=<your-PAT>
# Clone the imported Azure repo to the new folder in Rover container's context
# https://github.com/MicrosoftDocs/azure-devops-docs/issues/2455#issuecomment-439503194
$ git clone https://anything:$AZURE_DEVOPS_PAT@dev.azure.com/$AZURE_DEVOPS_ORGANIZATION/$AZURE_DEVOPS_PROJECT/_git/$AZURE_DEVOPS_PROJECT /tf/caf-custom
```
5. Initialize Rover & provision Launchpad

```bash
$ cd $HOME
$ rover login

# Select subscription where Lanzing Zones are provisioned
$ az account set -s <your-subscription-id>
# Bootstrap Terraform remote state by deploying Launchpad (level 0)
$ rover /tf/caf/landingzones/launchpad apply -launchpad -var-file="/tf/caf-custom/tfvars/sandpit/launchpad_opensource_light.tfvars"
```

6. Deploy the landing zone

```bash
# check that plan executes ok
$ rover /tf/caf-custom/landingzones/level1_landingzone_example plan -var-file="/tf/caf-custom/tfvars/sandpit/level1_landingzone_example.tfvars"
# deploy the lz
$ rover /tf/caf-custom/landingzones/level1_landingzone_example apply -var-file="/tf/caf-custom/tfvars/sandpit/level1_landingzone_example.tfvars"
```

7. Test that it works - by trying to add new rg to the sub without tags

```bash
$ az group create -l westeurope -n my-test-rg
Resource 'my-test-rg' was disallowed by policy. Policy identifiers: '[{"policyAssignment":{"name":"Require the managedBy tag on resource groups","id":"/subscriptions/<your subscription id>/providers/Microsoft.Authorization/policyAssignments/require-managed-by-tag"},"policyDefinition":{"name":"Require a tag on resource groups","id":"/providers/Microsoft.Authorization/policyDefinitions/96670d01-0a4d-4649-9c89-2d3abc0a5025"}}]'.
```

8. Cleanup

```bash
# Note the order - destroy the landing zones before launchpad
$ rover /tf/caf-custom/landingzones/level1_landingzone_example destroy -var-file="/tf/caf-custom/tfvars/sandpit/level1_landingzone_example.tfvars" -auto-approve
$ rover /tf/caf/landingzones/launchpad destroy -launchpad -var-file="/tf/caf-custom/tfvars/sandpit/launchpad_opensource_light.tfvars" -auto-approve
```

{% blockquote %}
You can only have one Launchpad per Azure subscription. This is by design.
{% endblockquote %}

## Continuous deployment using Azure DevOps

Now that you've seen how to deploy a landing zone locally using Rover you're probably wondering how to do the same from CI/CD. Azure DevOps provides hosted agents which are the quickest way to get started with your Azure Pipelines. CAF TF landing zones documentation contains [instructions for this nowadays](https://github.com/Azure/caf-terraform-landingzones/blob/master/documentation/delivery/intro_ci_ado.md) but it still only covers the more complex approach, using a self-hosted ADO agent.

{% blockquote %}
You don't want to spend time at the beginning of a project setting up a build machine just to get started.
{% endblockquote %}

Since deployment from the local environment is done in container context, the same should apply to the pipeline as well. ADO supports container-based CI/CD pipelines - they're called [YAML pipelines](https://docs.microsoft.com/en-us/azure/devops/pipelines/yaml-schema?view=azure-devops&tabs=schema%2Cparameter-schema). Just make sure to use the same container image that your Dev Container uses. 

Check the correct _container image version_ from `/tf/caf/.devcontainer/docker-compose.yml`

```yml
#-------------------------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See https://go.microsoft.com/fwlink/?linkid=2090316 for license information.
#-------------------------------------------------------------------------------------------------------------
 
  version: '3.7'
  services:
    rover:
      image: aztfmod/rover:2007.0108
  ...
```

**Note: The Rover tool is developed actively and version changes over time.**

### My solution for ADO hosted agents

After a lot of testing and troubleshooting, I managed to get Rover function properly with ADO hosted agents. Sigh, I wish YAML pipelines would support dry runs from the local machine. Maybe one day.

Here's MVP of `azure-pipelines.yml` for enabling continuous deployment to the **dev** environment

```yml
name: "caf_landingzone_example"

variables:
  location: 'westeurope'
  workspace: 'dev'
  
trigger: none
  
pool:
  vmImage: 'ubuntu-latest'
  
container:
  image: aztfmod/rover:2007.0108
  options: --user 0 --name rover-container -v /usr/bin/docker:/tmp/docker:ro
  env:
    TF_CLI_ARGS: '-no-color'
    ARM_CLIENT_SECRET: $(ARM_CLIENT_SECRET)
    ARM_CLIENT_ID: $(ARM_CLIENT_ID)
    ARM_SUBSCRIPTION_ID: $(ARM_SUBSCRIPTION_ID)
    ARM_TENANT_ID: $(ARM_TENANT_ID)
  
steps:
- script: |
    /tmp/docker exec -t -u 0 rover-container \
    sh -c "yum install -y sudo"
  displayName: 'Set up sudo'
- script: |
    ls -la
    sudo chmod -R 777 /home/vscode
    sudo chmod -R 777 /tf/launchpads
  displayName: 'File permissions'
- script: |
    az login --service-principal -u '$(ARM_CLIENT_ID)' -p '$(ARM_CLIENT_SECRET)' --tenant '$(ARM_TENANT_ID)'
    az account set -s  $(ARM_SUBSCRIPTION_ID)

    export ARM_CLIENT_ID=$(ARM_CLIENT_ID)
    export ARM_CLIENT_SECRET=$(ARM_CLIENT_SECRET)
    export ARM_TENANT_ID=$(ARM_TENANT_ID)
    export ARM_SUBSCRIPTION_ID=$(ARM_SUBSCRIPTION_ID)
  displayName: 'Login to Azure'
- script: |
    id=$(az storage account list --query "[?tags.tfstate=='level0']" -o json | jq -r .[0].id)
      if [ "${id}" == "null" ]; then
        /tf/rover/launchpad.sh /tf/launchpads/launchpad_opensource_light apply -var-file="$(Build.SourcesDirectory)/tfvars/$(workspace)/launchpad_opensource_light.tfvars"
    fi
  displayName: 'Initialize Launchpad (light) for DEV environment'
  condition: and(succeeded(), ne(variables.DESTROY , 'true'))
- script: |
    /tf/rover/launchpad.sh workspace create $(workspace)
  displayName: 'Create workspace for DEV environment'
  condition: and(succeeded(), ne(variables.DESTROY , 'true'))
  env:
    TF_VAR_workspace: $(workspace)
- script: |
    /tf/rover/rover.sh $(Build.SourcesDirectory)/landingzones/level1_landingzone_example apply -w $(workspace) -env $(workspace) -level level1 -var-file="$(Build.SourcesDirectory)/tfvars/$(workspace)/level1_landingzone_example.tfvars"
  displayName: 'Provision example Landing Zone for DEV environment'
  condition: and(succeeded(), ne(variables.DESTROY , 'true'))
- script: |
    /tf/rover/rover.sh $(Build.SourcesDirectory)/landingzones/level1_landingzone_example destroy -w $(workspace) -env $(workspace) -level level1 -var-file="$(Build.SourcesDirectory)/tfvars/$(workspace)/level1_landingzone_example.tfvars" -auto-approve
    /tf/rover/launchpad.sh /tf/launchpads/launchpad_opensource_light destroy -var-file="$(Build.SourcesDirectory)/tfvars/$(workspace)/launchpad_opensource_light.tfvars" -auto-approve
  displayName: 'Clean up resources'
  condition: and(succeeded(), eq(variables.DESTROY , 'true'))
```

These are the main challenges I had to tackle
- You need to provide `--user 0` in the container options
- Running `sudo` is not supported in the YAML pipelines, it required a small hack to get it working
- How to pass the correct parameters to `rover.sh`, this is not really documented

### Creating the Service Principal

The first thing you need is a _Service Principal_ to serve as the identity for the pipeline. 

There are [two different versions](https://github.com/aztfmod/level0#which-launchpad-to-use) of the _Launchpad_

- **launchpad_opensource**: for full blown GitOps
- **launchpad_opensource_light**: for more lightweight use

I haven't tested the heavier version yet but so far the light version has been enough for my needs. The documentation on the security requirements for initializing the Launchpad is [described here](https://github.com/aztfmod/level0/blob/master/launchpads/launchpad_opensource/documentation/permissions.md) but for **launchpad_opensource_light** it's only stated the Service Principal (SP) requires a Contributor RBAC role on the Azure subscription level. 

I figure the launchpad's implementation has changed since because there were additional permissions needed for the SP that finally got things working properly. You can check [my Terraform code](https://github.com/Masahigo/caf-terraform-landingzone-example/blob/master/bootstrap_sp/ad_roles.tf) for more details. 

{% blockquote %}
Long story short: I ended up implementing the bootsrap for the SP itself using Terraform.
{% endblockquote %}

### Setting up the pipeline

Here are instructions on how to get your pipeline set up with ease. I've spent some extra time making sure the example really works.

**Create and run**

```bash
# Navigate to custom repo root in Rover container context
$ cd /tf/caf-custom/

# Create the CD pipeline 
# Using DEV environment as an example here
$ PIPELINE_NAME='dev.lz.cd'
$ PIPELINE_DESCRIPTION='DEV Landing Zone example - Continuous Delivery'
$ REPO_YAML_PATH='pipelines/dev/azure-pipelines.yml'
$ FOLDER_PATH='\pipelines\dev'

# Create folder for the pipeline
$ az pipelines folder create --path "$FOLDER_PATH"

# Create the pipeline - skipping first run
$ az pipelines create --name "$PIPELINE_NAME" \
    --description "$PIPELINE_DESCRIPTION" \
    --repository "$AZURE_REPO_NAME" \
    --repository-type tfsgit \
    --branch master \
    --yml-path "$REPO_YAML_PATH" \
    --folder-path "$FOLDER_PATH" \
    --skip-first-run

# Bootstrap the Service Principal needed in the pipeline
# Accept the defaults (sub id, tenant id, user account) when it asks about them
$ cd bootstrap_sp/
$ chmod +x ./deploy.sh
$ ./deploy.sh

$ SERVICE_PRINCIPAL_NAME=$(terraform show -json terraform.tfstate | jq -r .values.outputs.bootstrap_ARM_CLIENT_ID.value)
$ CLIENT_SECRET=$(terraform show -json terraform.tfstate | jq -r .values.outputs.bootstrap_ARM_CLIENT_SECRET.value)
$ SUBSCRIPTION_ID=$(terraform show -json terraform.tfstate | jq -r .values.outputs.bootstrap_ARM_SUBSCRIPTION_ID.value)
$ TENANT_ID=$(terraform show -json terraform.tfstate | jq -r .values.outputs.bootstrap_ARM_TENANT_ID.value)

# Store SP's credentials to ADO variables
$ az pipelines variable create --name ARM_TENANT_ID --secret true --value $TENANT_ID --pipeline-name "$PIPELINE_NAME"
$ az pipelines variable create --name ARM_SUBSCRIPTION_ID --secret true --value $SUBSCRIPTION_ID --pipeline-name "$PIPELINE_NAME"
$ az pipelines variable create --name ARM_CLIENT_ID --secret true --value $SERVICE_PRINCIPAL_NAME --pipeline-name "$PIPELINE_NAME"
$ az pipelines variable create --name ARM_CLIENT_SECRET --secret true --value $CLIENT_SECRET --pipeline-name "$PIPELINE_NAME"

# Trigger new pipeline run manually
$ az pipelines run --name $PIPELINE_NAME
```

**Clean up**

```bash
# Remove the resources created through pipeline
$ az pipelines run --name $PIPELINE_NAME --variable "DESTROY=true"

# Remove ADO Project
$ az devops project delete --id $(az devops project show -p "$AZURE_DEVOPS_PROJECT" --query id -o tsv) -y

# Remove bootstrap SP
$ cd /tf/caf-custom/bootstrap_sp/
$ terraform destroy -auto-approve
```
