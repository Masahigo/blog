---
layout: photo
title: Interacting with Azure Blob Storage using AAD credentials
tags:
  - Azure Blob Storage
  - Azure AD
  - VSCode
  - .NET Core
  - Node.JS
photos:
  - /images/photos/azure-blob-aad-dotnetcore-nodejs.png
categories:
  - Azure
  - SDKs
  - Cross-platform development
date: 2020-05-24 23:53:05
---


Within the last year or so, Azure Storage finally received support for Azure AD authentication. More secure access and less credentials to manage, sounds like a no-brainer to me.

<!-- more -->

## Setting the stage

Blob Storage is one of the fundamental services of Azure that have existed since day one. Azure just turned ten years in Feb 2020 so you can do the math. It's a PaaS offering that keeps on evolving constantly. Other public cloud platforms have similar services, it's one of those basic building blocks you cannot cope without when building applications to public cloud. There's been an increasing amount of reports on ransomware from companies who've failed to protect their data properly. Microsoft has been investing heavily to make Azure's services as secure as possible. As a result, [Azure Storage finally received proper support for Azure Active Directory access control](https://azure.microsoft.com/en-us/blog/azure-storage-support-for-azure-ad-based-access-control-now-generally-available/) late last year. Before you had to always play around with Storage Account's own credentials. Now you can use AAD backed RBAC for more granular data access permissions, have full audit trail for it's [access logs](https://docs.microsoft.com/en-us/rest/api/storageservices/storage-analytics-log-format) and utilize [MSI for auth](https://docs.microsoft.com/en-us/azure/storage/common/storage-auth-aad-msi) in the apps hosted in Azure interacting with Azure Storage which means less application secrets to worry about.

I'm not a big fan of application credentials myself. I like to take advantage of [Managed Identities](https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview) and/or Azure AD service principals whenever possible and let Azure AD handle the security for me. This feature came a bit late when comparing to other major competitors (AWS, GCP) but now that it's there you've got no excuse for not using it. Microsoft is strongly encouraging the use of Azure AD credentials whenever interacting with Azure Storage.

## Azure Storage libraries and local development

I've been working on a personal project of mine during the last couple of weeks and had the change to try this out both with Node.JS as well as .NET Core. There's good client libraries available for both of them, which is not a surprise really as they're both first class citizens in Azure. 

For more details check the GitHub repos:

- [Azure Storage client library for JavaScript](https://github.com/Azure/azure-sdk-for-js/tree/master/sdk/storage)
- [Azure Storage libraries for .NET](https://github.com/Azure/azure-sdk-for-net/tree/master/sdk/storage)

### Local development using VSCode

I prefer to use VSCode in projects as it's well suited for cross-platform development. It also offers excellent tooling for debugging and there's tons of good extensions available.

Here are my recommendations for VSCode extensions:

- General
  - [Shell launcher](https://marketplace.visualstudio.com/items?itemName=Tyriar.shell-launcher) - **my absolute favorite!**
- Node.JS
  - [JavaScript Debugger (Nightly)](https://marketplace.visualstudio.com/items?itemName=ms-vscode.js-debug-nightly)
  - [Remote WSL](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-wsl)
- .NET Core
  - [C#](https://marketplace.visualstudio.com/items?itemName=ms-dotnettools.csharp)

For local environment variables, keep it simple and use `.env` file. This ensures that dev environment can be run locally even without VSCode or specific OS. It also makes your app easy to containerize, which should be your primary method for hosting it.

### Authenticating with DefaultAzureCredential

The official _Azure Identity library_ from Microsoft has this concept of `DefaultAzureCredential`. It gives you an easy way to handle Azure AD authentication from your code. The way this library works is that it first tries to look for Service Principal credentials from the host's environment variables. If they're not found it tries to fallback to host's managed identity as an authentication source. It's pretty cool, does all the heavy lifting for you.

The hardest part is actually configuring the [prerequisites in place](https://github.com/Azure/azure-sdk-for-js/tree/master/sdk/storage/storage-blob#create-the-blob-service-client):

1) Register a new AAD application and give permissions to access Azure Storage on behalf of the signed-in user
2) Grant access to Azure Blob data with RBAC
3) Configure Service Principal credentials in your environment variables

The first two steps are explained in [MS documentation here](https://docs.microsoft.com/fi-fi/azure/storage/common/storage-auth-aad). I have a [script which automates these](https://github.com/Masahigo/Node-Media-Server/blob/master/deployment/create-aci-resources.sh#L40).

As the third step, save the credentials to a local environment file `.env` in the root of your app:

```text
# .env
# Depending on your language (Node.JS / .NET Core)
# NODE_ENV=development
# ASPNETCORE_ENVIRONMENT=Development
AZURE_STORAGE_ACCOUNT_NAME=<your blob storage account's name>
AZURE_TENANT_ID=<your tenant id>
AZURE_CLIENT_ID=<your sp's client/app id>
AZURE_CLIENT_SECRET=<your sp's client secret>

```

After this you just have to make sure the environment variables are passed in properly in your app's startup. In Node.JS you can use [the dotenv package on npm](https://www.npmjs.com/package/dotenv). In .NET Core the best way to do this is using [dotenv.net from NuGet](https://www.nuget.org/packages/dotenv.net/).

### Node.JS

Install the needed _npm packages_:

```bash
npm install @azure/storage-blob @azure/identity dotenv
```

[Example code](https://github.com/Azure/azure-sdk-for-js/blob/master/sdk/storage/storage-blob/samples/javascript/azureAdAuth.js) for accessing Blob Storage with AAD credentials:

```javascript
const { BlobServiceClient } = require("@azure/storage-blob");
const { DefaultAzureCredential } = require("@azure/identity");

// Load the .env file if it exists
require("dotenv").config();

async function main() {
  // Enter your storage account name
  const account = process.env.AZURE_STORAGE_ACCOUNT_NAME || "";

  // Azure AD Credential information is required to run this sample:
  if (
    !process.env.AZURE_TENANT_ID ||
    !process.env.AZURE_CLIENT_ID ||
    !process.env.AZURE_CLIENT_SECRET
  ) {
    console.warn(
      "Azure AD authentication information not provided, but it is required to run this sample. Exiting."
    );
    return;
  }

  const defaultAzureCredential = new DefaultAzureCredential();

  const blobServiceClient = new BlobServiceClient(
    `https://${account}.blob.core.windows.net`,
    defaultAzureCredential
  );

  // Create a container
  const containerName = `newcontainer${new Date().getTime()}`;
  const createContainerResponse = await blobServiceClient
    .getContainerClient(containerName)
    .create();
  console.log(`Created container ${containerName} successfully`, createContainerResponse.requestId);
}

main().catch((err) => {
  console.error("Error running sample:", err.message);
});

```

### .NET Core

This example is based on a console application. That's where most of us .NET devs usually start with when testing our code :)

Install the needed _NuGet packages_:

```bash
dotnet add package Azure.Storage.Blobs
dotnet add package Azure.Identity
dotnet add package dotenv.net

```

Modify `Program.cs` to print out all container and blob names in the given storage account:

```c
using Azure.Identity;
using Azure.Storage.Blobs;
using dotenv.net;
..

static async Task Main(string[] args) {
  
  DotEnv.Config();

  var environmentName = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT");

  IConfiguration Configuration = new ConfigurationBuilder()
  .SetBasePath(Directory.GetCurrentDirectory())
  .AddJsonFile($"appsettings.{environmentName}.json", optional: false, reloadOnChange: true)
  .AddEnvironmentVariables()
  .Build();

  var storageAccount = Configuration["AZURE_STORAGE_ACCOUNT_NAME"];

  Uri accountUri = new Uri(String.Format("https://{0}.blob.core.windows.net/", storageAccount));
  BlobServiceClient client = new BlobServiceClient(accountUri, new DefaultAzureCredential());

  await foreach (var container in client.GetBlobContainersAsync())
  {
    Console.WriteLine(container.Name);
    var containerClient = client.GetBlobContainerClient(container.Name);
    
    await foreach (var blob in containerClient.GetBlobsAsync())
    {
      Console.WriteLine(blob.Name);
    }
  }

}

```

You can also find [an example from MS documentation](https://docs.microsoft.com/en-us/azure/storage/common/storage-auth-aad-msi#net-code-example-create-a-block-blob).

## User delegation SAS tokens

There are also use cases where one needs to create a SAS token for a container or blob on the fly. This is achieved using a concept called [user delegation SAS](https://docs.microsoft.com/en-us/rest/api/storageservices/create-user-delegation-sas). This enables us to authorize creation of SAS token using Azure AD credentials instead of the _account key_ which gives full access to your Storage Account and that should be protected at all cost.

In .NET Core this is [very straighforward](https://docs.microsoft.com/en-us/azure/storage/blobs/storage-blob-user-delegation-sas-create-dotnet) - you just acquire the `UserDelegationKey`:

```c
using Azure.Identity;
using Azure.Storage.Sas;
using Azure.Storage.Blobs;
using Azure.Storage.Blobs.Models;
using dotenv.net;

static async Task Main(string[] args) {

  // Builds on previous example
  ..
  await foreach (var blob in containerClient.GetBlobsAsync())
  {
    // Create a SAS token that's valid for one hour.
    BlobSasBuilder sasBuilder = new BlobSasBuilder()
    {
      BlobContainerName = container.Name,
      BlobName = blob.Name,
      Resource = "b",
      StartsOn = DateTimeOffset.UtcNow,
      ExpiresOn = DateTimeOffset.UtcNow.AddHours(1)
    };

    // Specify read permissions for the SAS.
    sasBuilder.SetPermissions(BlobSasPermissions.Read);

    UserDelegationKey key = await client.GetUserDelegationKeyAsync(DateTimeOffset.UtcNow, 
                                                                   DateTimeOffset.UtcNow.AddDays(7));

    string sasToken = sasBuilder.ToSasQueryParameters(key, storageAccount).ToString();

    // Construct the full URI, including the SAS token.
    fullUri = new UriBuilder()
    {
      Scheme = "https",
      Host = string.Format("{0}.blob.core.windows.net", storageAccount),
      Path = string.Format("{0}/{1}", container.Name, blob.Name),
      Query = sasToken
    };

    // Print out url to blob with sas token
    Console.WriteLine("fullUri: " + fullUri);

    // get only the first one for testing
    break;
  }

```

[Powershell](https://docs.microsoft.com/en-us/azure/storage/blobs/storage-blob-user-delegation-sas-create-powershell) and [Azure CLI](https://docs.microsoft.com/en-us/rest/api/storageservices/create-user-delegation-sas) also support this OOB.

## Afterthoughts

Microsoft has done a really good job on these latest Azure SDKs. It was very straightforward to get started with using the blob storage client libraries for both languages. I like the idea of using common practises like local `.env` files and `DefaultAzureCredential` makes it so easy to handle the AAD authentication part under the hood. So far I've been using purely the service principal credentials but I'll test this soon also using Managed Identity in Azure service.
