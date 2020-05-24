---
title: Running Azure CLI & AzCopy from Linux container
tags:
  - Azure CLI
  - AzCopy
photos:
  - /images/photos/azure-cli-logo.jpg
categories:
  - CI/CD
  - Azure
  - Docker
  - Linux
date: 2020-05-24 13:14:41
---


Azure CLI is a powerful tool. Bake it into Docker and you have the perfect toolkit for running your container based CI jobs targeting Azure. If only it was that simple.

<!-- more -->

## Why should I care?

Running CI/CD in today's world is mostly container based. All the popular CI services like GitHub, Gitlab, BitBucket, Cloud Build, CircleCI, Drone.. they all pretty much rely on the fact that your CI jobs are run in containers. Azure DevOps makes an exception here as it introduced the concept of "container jobs" about a year ago, and therefore the support for this isn't that good yet.

By taking advantage of containers in the CI/CD process makes it very flexible. You are not tied to a specific set of tools (or even the CI service), you pick and choose the ones you need and fit the best to your requirements. But what it also means, in most of the cases, is that the underlying OS is Linux and the container runtime is Docker. Some of the CI services are starting to support also Windows based containers, though still a minority.

Of course one could argue that you should use declarative approach and handle everything with IaC, in Azure's case with ARM or Terraform. In reality you just can't get full automation accomplished with those alone. That's when scripting comes into play. Companies coming from e.g. OS background prefer to use bash and Azure CLI over other options here. And when you start thinking about automation you soon realize those scripts should be tested in the same context that your CI is using..

## Getting started

You basically have two options: 

1) Build your own Docker image and install Azure CLI there 
2) Use the [official one from Docker Hub](https://hub.docker.com/_/microsoft-azure-cli) that Microsoft provides: `mcr.microsoft.com/azure-cli`

I recommend the second option if you're not interested in re-inventing the wheel and maintaining the container image yourself. It does come with a few downsides: the image is quite big (1.13GB currently) and is based on _Alpine_ Linux distro. 

Microsoft offers also [basic instructions](https://docs.microsoft.com/en-us/cli/azure/run-azure-cli-docker?view=azure-cli-latest) for getting started with running Azure CLI in Docker.

## Authentication to Azure

Now this is where the basic instructions fall short. Automation in mind you want to test these things using Service Principal from day one.

Start by [creating a new Service Principal](https://docs.microsoft.com/en-us/cli/azure/create-an-azure-service-principal-azure-cli?view=azure-cli-latest#password-based-authentication):

```bash
# Login with your user account (which has the needed privileges to create new SPNs)
$ az ad sp create-for-rbac --name ServicePrincipalName
{
  "appId": "xxx",
  "displayName": "ServicePrincipalName",
  "name": "http://ServicePrincipalName",
  "password": "xxx",
  "tenant": "xxx"
}

```

Save these credentials to a local environent file `.env.local`:

```
ARM_CLIENT_ID=<appId>
ARM_CLIENT_SECRET=<password>
ARM_TENANT_ID=<tenant>
ARM_SUBSCRIPTION_ID=<your Azure subscription>

```

Run the Docker container locally and test login with Service Principal:

```bash
$ docker run --env-file ./.env.local -it --rm \
--name azure-cli-ci mcr.microsoft.com/azure-cli:2.3.1 /bin/bash

bash-5.0# az login --service-principal -t $ARM_TENANT_ID -u $ARM_CLIENT_ID -p $ARM_CLIENT_SECRET
...
bash-5.0# az account set --subscription $ARM_SUBSCRIPTION_ID
bash-5.0# az account show --query [name,user]
[
  "<your Azure subscription>",
  {
    "name": "http://ServicePrincipalName",
    "type": "servicePrincipal"
  }
]

```

{% blockquote %}
Note: It's always a good idea to lock down the version of your Azure CLI.
{% endblockquote %}

## Utilizing Linux date command for SAS

The _Alpine_ Linux distro _does not support -d options_ out of the box. Many of the examples on MS docs site _for generating sas tokens_ rely on this. To enable it you need to install some extras to the container on the fly:

```bash
# add coreutils package to support -d options
bash-5.0# apk add --update coreutils && rm -rf /var/cache/apk/*

```

After this you can use the _date_ command more flexibly:

```bash
# Current time
bash-5.0# date -u '+%Y-%m-%dT%H:%MZ'
2020-05-24T09:04Z

# Create a timestamp in UTC format 30 minutes from current time
bash-5.0# date -u -d "30 minutes" '+%Y-%m-%dT%H:%MZ'
2020-05-24T09:35Z

```

## Using AzCopy with SAS

[AzCopy](https://docs.microsoft.com/en-us/azure/storage/common/storage-use-azcopy-v10) is a powerful tool for copying or moving data to Azure Storage. About 99,9% of Azure projects out there use Azure Blob Storage for various data needs. If you need to let's say move hundreds of files to blob storage efficiently - this is the tool you should be using. It supports both _Azure AD and SAS_ as authorization mechanisms nowadays, but to support _all scenarios_ SAS is the only option still. Building the SAS token from Docker container is an art of it's own as well.

AzCopy can be installed to the container on the fly:

```bash
# https://docs.microsoft.com/en-us/azure/storage/common/storage-use-azcopy-v10#use-azcopy-in-a-script
echo "Setup AzCopy.."
mkdir -p tmp
cd tmp
wget -O azcopy_v10.tar.gz https://aka.ms/downloadazcopy-v10-linux && tar -xf azcopy_v10.tar.gz --strip-components=1
cp ./azcopy /usr/bin/
cd ..

# Check that azcopy command works from container
bash-5.0# azcopy --version
azcopy version 10.4.3

```

A working solution for generating a SAS token:

```bash
#STORAGE_ACCOUNT_NAME=<your storage account name - passed in from env variable>

echo "Create SAS token.."
EXPIRE=$(date -u -d "3 months" '+%Y-%m-%dT%H:%M:%SZ')
START=$(date -u -d "-1 day" '+%Y-%m-%dT%H:%M:%SZ')

echo "Get account key for storage account"
STORAGE_ACCOUNT_KEY=$(az storage account keys list \
 -g $RESOURCE_GROUP_NAME \
 --account-name $STORAGE_ACCOUNT_NAME \
  --query "[0].value" \
  --output tsv)

AZURE_STORAGE_SAS_TOKEN=$(az storage account generate-sas \
 --account-name $STORAGE_ACCOUNT_NAME \
 --account-key $STORAGE_ACCOUNT_KEY \
 --start $START \
 --expiry $EXPIRE \
 --https-only \
 --resource-types sco \
 --services b \
 --permissions dlrw -o tsv | sed 's/%3A/:/g;s/\"//g')

```

Example of copying files to blob storage from your local file system with AzCopy and SAS:

```bash
# Create local folder `files` and put some files there for testing

# Mounts you current working directory to the container
docker run --env-file ./.env.local -it --rm \
--name client-ci -v `pwd`:`pwd` -w `pwd` mcr.microsoft.com/azure-cli:2.3.1 /bin/bash

# Add coreutils package, install AzCopy and configure SAS token - see examples from previous steps

# Define helper function for copying files
az_copy_to_blob_storage(){
  echo "Source path: ${1}"
   if [ `az storage blob list -c ${2} --account-name $STORAGE_ACCOUNT_NAME --sas-token $AZURE_STORAGE_SAS_TOKEN --query "length([])"` == 0 ]; then
        echo "Blob container is empty. Skip removal.."
  else
    echo "Remove current files from blob storage container.."
    azcopy rm "https://$STORAGE_ACCOUNT_NAME.blob.core.windows.net/${2}?$AZURE_STORAGE_SAS_TOKEN" --recursive=true
  fi
  echo "Copy new files from source path to blob storage container.."
  azcopy cp "${1}/*" "https://$STORAGE_ACCOUNT_NAME.blob.core.windows.net/${2}?$AZURE_STORAGE_SAS_TOKEN" --recursive
}

#CONTAINER_NAME=<your blob storage container name where files are to be copied>
echo "Copy build folder contents to blob storage using AzCopy.."
SOURCE_PATH="$(pwd)/files"

az_copy_to_blob_storage $SOURCE_PATH $CONTAINER_NAME

```

{% blockquote %}
You can find a more complete example of utilizing these snippets for a Single Page App's CD pipeline [from here](https://github.com/Masahigo/dev-playground/tree/master/client#testing-ci-via-docker-container).
{% endblockquote %}

## Some gotchas

These examples are based on a real world project. There are a couple of things to keep in mind here that I've stumbled on.

**AzCopy**

- The tool can only work on blob storage container level. Meaning you cannot copy directly to the root of blob storage, you always need a blob container first
- It supports synchronization but that feature is not really suitable for CI/CD scenarios. If you need to update existing files with new ones, it's always better to remove the current files and then copy new ones. It doesn't support "updating over existing ones" when using the `recursive` flag.

**Windows 10 / WSL**

When working from WSL take note that the computer time ofter lags with the current time in the Docker container. This is a [known bug with Docker for Windows](https://github.com/docker/for-win/issues/4526). The best you can do is to _restart the Docker for Windows_ before starting to work on your container based CI/CD script. You will save a lot of time troubleshooting issues with Azure CLI and blob storage, trust me.
