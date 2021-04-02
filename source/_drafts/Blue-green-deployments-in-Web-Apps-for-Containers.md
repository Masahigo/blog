---
title: Blue-green deployments in Web Apps for Containers
tags:
  - Azure App Service
  - Azure Container Registry
  - Azure CLI
  - Terraform
photos:
  - /images/photos/appservice-linux-blue-green.png
categories:
  - Azure
  - CI/CD
  - Docker
  - Linux
---

Taking full control of your zero downtime deployments in Azure App Service on Linux.

<!-- more -->

## App Service - The holy grail of Azure PaaS

It was roughly 7 years ago when I started to learn about Azure. Around those times the default way of hosting web applications on Azure PaaS was to use [Azure Cloud Services](https://docs.microsoft.com/en-us/azure/cloud-services/cloud-services-choose-me). It felt like a complex service to manage and comprehend back then. 3 years later I'm working on my first real Azure project and being responsible for the whole infra. Azure is no longer called _the Microsoft Azure_, the [classic deployment model](https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/deployment-models#history-of-the-deployment-models) has been depracated in favor of ARM deployments and there's this new service called the "App Service" which feels way more intuitive and works very well for running .NET based workloads. After several Azure projects to follow, in which the same service was used for running different kinds of .NET based web applications, both frontend and backend, this service never failed me down. 

But what about running Linux based workloads on it? [Microsoft announced GA for App Service on Linux](https://www.infoq.com/news/2017/09/Azure-App-Service-Linux/) in late 2017. This was the first time I encountered the term "Web Apps for Containers". We tried it out in a project back then to host a custom, Java based application which was containerized. It worked ok but felt a bit unmature those days. Fast forward to present and it supports almost all of the features that its .NET counterpart does. 

I wanted to see if it was possible to use the same methods learned from previous projects and achieve zero downtime deployments _the App Service way_. **It was time to battle test it**.
