---
layout: photo
photos:
 - /images/photos/ps-logo-small.png
title: New beginnings
date: 2019-01-23 14:00:00
tags:
- Google Cloud Platform
- Deployment Manager
- Infrastructure as Code
- Cloud IAM
- Google Cloud Build
- Google App Engine
categories:
- CI/CD
- GCP
---

After working over 10 years in different roles in the IT industry I felt like I needed a change. I needed to break the routine and jump out of my comfort zones into the unknown.

<!-- more -->

## Prologue

I had started to lean towards devops and more often found myself avoiding other areas in projects. How cool would it be if I could just concentrate into this one area and develop my skills there to the fullest?

Well, my wish became reality when I joined [PolarSquad](https://www.polarsquad.com/) on the 1st of October 2018. This was the biggest leap of faith I have done during my career so far but it has felt like the right one from day one. Docker is no longer a stranger to me and running builds using containers already feels natural to me. Coming from MS tech background where containers are not yet an everyday thing there's always something new to learn.

## How this blog was born

I had been thinking about starting my own blog for several years already but had not had the proper time nor motivation to get started with it. After jumping into a new company it felt like the right time.

{% raw %}
<div style="width:100%;height:0;padding-bottom:66%;position:relative;">
<iframe src="https://giphy.com/embed/jndc0TQq9fvK8" width="100%" height="100%" style="position:absolute" frameBorder="0" class="giphy-embed" allowFullScreen></iframe></div>
{% endraw %}

1. _Where am I going to host this website?_ I had been learning about **Google Cloud Platform** recently and was anxious to try out something real there so this was a no brainer to me. I could have used just GitHub Pages to be honest but what would be the fun with that!

1. _What platform should I use for the blog?_ I had been reading about [JAMStack](https://jamstack.org/) a year ago and found one particular static website generator called **Hexo** which felt like a good choice so I went with that.

1. _What service in GCP should I utilize for hosting a static website?_ After going through all the possible options the **Google App Engine (GAE)** seemed like the best option - PaaS service that supports custom domains and SSL certs, what's not to like? It also downscales well so running cost is minimal.

It was time to start working on the [infrastructure](https://github.com/Masahigo/blog-infra).

### First you need a project

Anyone who has used GCP knows that everything begins with a project. So I started by figuring out how can I automate the creation of projects. I like to avoid manual steps whenever possible. It turned out to require couple of things.

1. **Organization**: if you want to automate the creation of projects in GCP you really need an organization in Cloud IAM. I had to create Cloud Identity for myself by validating it through the custom domain I registered for this website. It was free however.

1. **Project for creating other projects**: in order to create projects in automated fashion you need one "master project" aka _DM Creation Project_ under your organization which is responsible to provisioning new projects. You can find more details [here](https://github.com/Masahigo/blog-infra/tree/master/project_creation).

I ended up investing a lot more time into this than I had planned but I felt this might become handy in the future. Eventually every GCP customer has to deal with this when they start their journey with Google Cloud Platform. You have to be able to manage your projects properly when you start advancing further than POCs.

So after acquiring an organization in Cloud IAM and creating the _DM Creation Project_ - yes, these parts are done manually - I created a Deployment Manager (DM) template and schema for defining the actual GCP project where the website would be deployed.

- DM template for creating new projects: [project-creation-template.jinja](https://github.com/Masahigo/blog-infra/blob/master/project_creation/project-creation-template.jinja)
- Schema for the DM template: [project-creation-template.jinja.schema](https://github.com/Masahigo/blog-infra/blob/master/project_creation/project-creation-template.jinja.schema)

Since I was also using Cloud Build for executing the Deployment Manager deployment I needed to ensure it has sufficient permissions in the _DM Creation Project_. You can find the instructions [here](https://github.com/Masahigo/blog-infra/tree/master/project_creation#enabling-cloud-build).

{% asset_img cb-service-account-project-level-permissions.png CB Service ACcount Project level permissions %}

In addition you need to give following Cloud IAM roles for the _CB Service Account_ on the **organization level** to run `gcloud` commands for dynamically populating environment variables

- Billing Account Viewer
- Organization Viewer

As a result you should get something like this

{% asset_img project-creation-sa-permissions-org-level.png Project creation SA permissions on the organization level %}

Here's a recap of the CI/CD plan

- Provision the GCP Project for the blog from the _DM Creation Project_ using _CB Service Account_
- Provision the initial infrastucture for the blog from the _actual GCP Project_ **using it's own** _CB Service Account_
- Implement the deployment pipeline and once working create a Build Trigger for it

### CI/CD pipelines using Cloud Build

[Google Cloud Build](https://cloud.google.com/cloud-build/docs/overview) is a service for executing builds on GCPs infrastructure. It was previously known as _Google Container Builder_ and what it essentially does is that it spins up Docker containers on the fly and executes the commands that you specify in the given context. It's 100% Docker native and works amazingly fast. It supports only Linux based containers though so if you need to build .net code you need your own build machine to handle that part for you. What makes it different from similar services like GitLab CI is that Google provides a [Local Builder](https://cloud.google.com/cloud-build/docs/build-debug-locally) which makes it much more convenient to work on your build configs.

#### Infrastructure

_Disclaimer: To achieve a fully automated infrastructure provisioning would have required Cloud Build Triggers for the [blog-infra](https://github.com/Masahigo/blog-infra) repository but as I was learning by doing I decided to leave this part out from CI/CD for now. I did however create Google Cloud Build config files and submitted builds manually using those._

The infrastructure for the blog is very simple: one [App Engine service hosting the static website](https://cloud.google.com/appengine/docs/standard/python/getting-started/hosting-a-static-website). On top of that I'm utilizing [Cloud DNS](https://cloud.google.com/dns/docs/?hl=fi) for managing the DNS zone and records. For now I'm just using the root domain but my plan is to learn how to register subdomains dynamically and utilize those for eg. dev/qa environments.

Here are the commands used for the initial provisioning:

{% include_code Initial provisioning lang:sh initial-provisioning.sh %}

As you probaly noticed the App Engine itself did not require anything else than initialization in the project.

#### Deploying the blog to App Engine

This was the easy part. I had already figured out the commands I needed to run in the build context:

```sh
git clone --recurse-submodules https://github.com/Masahigo/blog.git
cd blog
npm install
npm install -g hexo-cli
hexo generate
cp -R blog/public/ CI/www/
gcloud app deploy ./CI/app.yaml
```

Without going into too much details a short explanation of the main points

- There's one Git submodule which points to a fork of Hexo's [NeXT theme](https://github.com/Masahigo/hexo-theme-next)
- The command `hexo generate` creates the static website content and renders it to subfolder `/public`
- This rendered version of the blog is then copied under subfolder `CI/www` because the App Engine expects all static files to be located under `www` subfolder
- The subfolder `CI` already contains the App Engine configuration for the static website: `app.yaml`
- The command `gcloud app deploy` packages the files in `www` folder and deploys those to the _default_ App Engine service

{% include_code app.yaml lang:yaml app-config-for-app-engine.yaml %}

The build config for executing the same commands resulted in

{% include_code cloudbuild.yaml lang:yaml build-config-for-blog.yaml %}

Testing the deployment from CLI:

```sh
gcloud builds submit --config=cloudbuild.yaml . --project=ms-devops-dude
```

After this it was fairly straightforward to create a Build Trigger to do the same every time there's new commit to _master_ in the blog's repository.

{% asset_img gcp-build-trigger-for-blog.png Build Trigger for blog website %}

### Some lessons learned

As you can imagine not everything went like in the movies when working on my first CI/CD pipelines on GCP. Here's a couple of obstacles I encountered along the way.

#### Environment Variables

The out-of-the-box environment variables in [Deployment Manager](https://cloud.google.com/deployment-manager/docs/configuration/templates/use-environment-variables) are quite limited. It also turned out that running `gcloud` commands in build step context and storing those into environment variables on the fly was not possibly. (Well, it would have required [substitutions](https://cloud.google.com/cloud-build/docs/configuring-builds/substitute-variable-values) but those can only persist static values)

I ended up in following kind of solution; Declare the environment variables in a [separate bash script](https://github.com/Masahigo/blog-infra/blob/master/project_creation/create-new-project.sh) where also `gcloud` command is called along with the variables passed in as template properties:

```sh
export GCP_PROJ_ID=`gcloud info |tr -d '[]' | awk '/project:/ {print $2}'`
export GCP_OWNER_ACCOUNT=`gcloud projects get-iam-policy $GCP_PROJ_ID --flatten='bindings[].members' --format='value(bindings.members)' --filter='bindings.role:roles/owner'`
export GCP_BILLING_ACCOUNT_ID=`gcloud beta billing accounts list --filter "My Billing Account" --format='value(ACCOUNT_ID)'`
export GCP_ORG_ID=`gcloud organizations list --filter "msdevopsdude.com" --format='value(ID)'`

gcloud deployment-manager deployments create $GCP_DEPLOYMENT_NAME --template project-creation-template.jinja
--properties="organization-id:'$GCP_ORG_ID',billing-account-id:$GCP_BILLING_ACCOUNT_ID,project-name:'$GCP_NEW_PROJECT_NAME',owner-account:'$GCP_OWNER_ACCOUNT'"
```

#### Utilize the entrypoint in build config

Google Cloud Builders allow you to override the default `entrypoint` in Docker. I found this very useful when executing bash script using [gcloud builder](https://github.com/GoogleCloudPlatform/cloud-builders/tree/master/gcloud):

```yaml
steps:
- name: gcr.io/cloud-builders/gcloud
  entrypoint: /bin/bash
  args:
  - -c
  - ./create-new-project.sh
  env:
  - GCP_DEPLOYMENT_NAME=ms-devops-dude
  - GCP_NEW_PROJECT_NAME=MS DevOps Dude
```

#### Git submodules

If you are referring to Git submodules in your main repo those are not checked out by default in Google Cloud Build. To get around this you can specify one additional build step in the beginning of the pipeline using the [git builder](https://github.com/GoogleCloudPlatform/cloud-builders/tree/master/git):

{% include_code Google cloud build config - include git submodules step lang:yaml build-step-include-submodules.yaml %}

#### Handle GAE appspot.com redirection for naked domain

Last thing I wanted to fix before going live with this website was to redirect the default App Engine url (ms-devops-dude.appspot.com) to my naked domain (msdevopsdude.com). There was a [blog post](https://code.luasoftware.com/tutorials/google-app-engine/appengine-redirect-domain/) about this but it didn't really cover my scenario that well.

**Here's what you basically need to do**

Create _a separate GAE service_ in my case I call it `redirect`

{% include_code redirect.yaml lang:yaml redirect-service-for-app-engine.yaml %}

Create `main.py` for the 301 logic

{% include_code main.py lang:python app-engine-redirect-logic.py %}

Override the routing rules in `dispatch.yaml`

```yaml
dispatch:
  - url: "ms-devops-dude.appspot.com/*"
    service: redirect

```

## Closing words

My first impression on Google Cloud Build is quite positive. It gets the job done and it's Docker support is superior. Google Cloud Build's [pricing](https://cloud.google.com/cloud-build/pricing) is also attractive: you get 120 minutes of free build time __per day__ and it allows you to run up to 10 concurrent builds __per project__. I will definitely continue my experimentations on it.

I hope you have enjoyed reading my first blog post. Until next time!
