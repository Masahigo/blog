---
title: New beginnings
date: 2019-01-18 16:00:32
tags:
- Google Cloud Platform
- Deployment Manager
- Infrastructure as Code
- Cloud IAM
- Google Cloud Build
---

## Prologue

After working over 10 years in different roles in the IT industry I felt like I needed a change. I needed to break the routine and jump out of my comfort zones into the unknown. I had started to fall in love with devops and more often found myself avoiding other areas in projects. How cool would it be if I could just concentrate into this one area and develop my skills there to the fullest?

Well, my wish became reality when I joined [PolarSquad](https://www.polarsquad.com/) on the 1st of October 2018. This was the biggest leap of faith I have done during my career so far and it has felt like the right one from day one. Docker is no longer a stranger to me and running builds using containers is super nice. Coming from MS background where containers are not yet an everyday thing there's always something new to learn.

## How this blog was born

I had been thinking about starting my own blog for several years already but had not had the proper time nor motivation to get started with it. After jumping into a new company it felt like the right time - "just do it".

1. _Where am I going to host this website?_ I had been learning about **Google Cloud Platform** recently and was anxious to try out something real there so this was a no brainer to me. I could have used just GitHub Pages to be honest but what would be the fun with that!

1. _What platform should I use for the blog?_ I had been reading about [JAMStack](https://jamstack.org/) a year ago and found one particular static website generator called **Hexo** which felt like a good choice so I went with that.

1. _What service in GCP should I utilize for hosting a static website?_ After going through all the possible options the **App Engine (Standard)** seemed like the best option - PaaS service that supports CNAMEs and SSL certs, what's not to like? It also downscales well so running cost is minimal.

It was time to start working on the [infrastructure](https://github.com/Masahigo/blog-infra).

### First you need a project

Anyone who has used GCP knows that everything begins with a project. So I started by figuring out how can I automate the creation of projects. I like to avoid manual steps whenever possible. It turned out to require couple of things

1. **Organization**: if you want to automate the creation of projects in GCP you really need an organization in Cloud IAM. I had to create Cloud Identity for myself by validating it through the custom domain I registered for this website. It was free however.

1. **Project for creating other projects**: in order to create projects in automated fashion you need one "master project" aka _DM Creation Project_ under your organization which is responsible to provisioning new projects. You can find more details [here](https://github.com/Masahigo/blog-infra/tree/master/project_creation).

I ended up investing a lot more time into this than I had planned but I felt this might become handy in the future because eventually every GCP customer has to deal with this when they start their journey with Google Cloud Platform. You have to be able to manage your projects properly when you start advancing further than POCs.

#### Provisioning with templates

So after acquiring an organization in Cloud IAM and creating the _DM Creation Project_ - yes, there parts are done manually - I created a Deployment Manager (DM) template and schema for defining the actual GCP project where the website would be deployed.

- DM template for creating new projects: [project-creation-template.jinja](https://github.com/Masahigo/blog-infra/blob/master/project_creation/project-creation-template.jinja)
- Schema for the DM template: [project-creation-template.jinja.schema](https://github.com/Masahigo/blog-infra/blob/master/project_creation/project-creation-template.jinja.schema)

Since I was also using Cloud Build for executing the Deployment Manager deployment I needed to ensure it has sufficient permissions in the _DM Creation Project_. You can find the instructions [here](https://github.com/Masahigo/blog-infra/tree/master/project_creation#enabling-cloud-build).

!Put image here!

In addition you need to give following Cloud IAM roles for the _CB Service Account_ on the **organization level**

- Billing Account Viewer
- Organization Viewer

!Put another image here!

### Taming the Google Cloud Build
