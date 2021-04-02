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

## Azure App Service

It was roughly 7 years ago when I started to learn about Azure. Around those times the default way of hosting web applications on Azure PaaS was to use [Azure Cloud Services](https://docs.microsoft.com/en-us/azure/cloud-services/cloud-services-choose-me). It felt like a complex service to manage and comprehend back then. 3 years later I'm working on my first real Azure project and being responsible for the whole infra. Azure is no longer called _the Microsoft Azure_, the [classic deployment model](https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/deployment-models#history-of-the-deployment-models) has been depracated in favor of ARM deployments and there's this new service called the "App Service" which feels way more intuitive and works very well for running .NET based workloads. After several Azure projects to follow, in which the same service was used for running different kinds of .NET based web applications, both frontend and backend, this service never failed me down. 

*But what about running Linux based workloads on it?* [Microsoft announced GA for App Service on Linux](https://www.infoq.com/news/2017/09/Azure-App-Service-Linux/) in late 2017. This was the first time I encountered the term "Web Apps for Containers". We tried it out in a project back then to host a custom, Java based application which was containerized. It worked ok but felt a bit unmature those days. For instance, it  lacked proper VNET integration. Fast forward to present and it supports almost all of the features that its .NET counterpart does.

I wanted to see if it was possible to use the same, well proven techniques learned from previous projects and achieve zero downtime deployments by utilizing the built-in features this *platform* has to offer.

## The basics

Before jumping ahead it's important to understand at least some basics and terms referenced throughout this blog post.

The multi-tenant Azure App Service consists of the following building blocks

- **App Service plan:** Hosting environment for your web applications (web apps). Comes in two flavors (managed Operation Systems): Windows & Linux. There are two types of web apps it supports: *App Services* and *Deployment slots*. *You can think of it as your webserver that Microsoft manages for you.* But it's a lot more than that really. It can be scaled up/down and also scaled in/out. This translates into changing its compute resources on the fly and the underlying load balancers handling the necessary routing under the hood. Microsoft has pre-provisioned pools of these managed VMs with different specs waiting to be requested by the service to consume and therefore operations like changing the pricing tier or the amount of instances takes usually around 10-20 seconds.

- **App Service:** Instance of your live web app. Depending on the App Service plan it was deployed to - it's either an IIS application or a Linux process. On Linux side it can also be deployed as a container, the deployment method that I prefer. I mean, who wants to use FTP in the 21st century or end up troubleshooting compatibility issues with the default Linux distro of the hosting environment.

App Service has a lot of features, which I'm not going to go through here in more detail, but *Application settings* (app settings) and *Deployment slots* are the important ones to grasp in regards to code deployments.

- **App settings:** Your web app's real-time configurations. If you modify these on a running web app, it gets restarted automatically. App Service takes care of injecting and making them available in the context of your running application.

- **Deployment slot:** Another instance of your app. You can deploy several of these and have them running side by side with your live web app. For blue-green deployments you need only one though and I like to call it *a staging slot*. It has all the features and functionalities of its parent (App Service) but it's possible to have also *slot specific* app settings that affect only the app running in the deployment slot. 

- **A swap:** Performing _a swap_ in App Service means replacing the live app (blue) with a running app from a deployment slot (green). When done correctly, and your app is stateless by design, the end user experience is not affected. App Service takes care of draining the remaining user sessions before completing the switch. In normal circumstances this shouldn't take longer than 30 seconds in total. By deploying your new code to a staging slot (green) first ensures the live app is never distrupted directly and allows you for validating it and making the decision whether to roll it out or not. App Service's managed load balancers are doing the heavy lifting here, you just define the source (staging slot) and target (live app) for the swap.

{% raw %}
<div style="width:100%;height:0;padding-bottom:100%;position:relative;"><iframe src="https://giphy.com/embed/YNxvJmicapfWgQUOhi" width="100%" height="100%" style="position:absolute" frameBorder="0" class="giphy-embed" allowFullScreen></iframe></div><p><a href="https://giphy.com/gifs/workingtitlefilms-simon-pegg-shaun-of-the-dead-nick-frost-YNxvJmicapfWgQUOhi">via GIPHY</a></p>
{% endraw %}

## Continuous deployments


