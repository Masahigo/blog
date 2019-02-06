---
layout: photo
title: Working with Docker for Windows and WSL
tags:
  - Docker for Windows
  - WSL
  - Cross-platform development
  - VSCode
photos:
  - images/docker-for-windows.jpg
categories:
  - Docker
  - Linux
date: 2019-02-06 23:24:40
---


Being a .NET developer in today's world requires more than just understanding the MS tech stack. OS based technologies have become defacto in many areas of software development. Microsoft is embracing the change and so should you.

<!-- more -->

## Words of motivation

There is a certain learning curve when it comes to adopting OS technologies. Especially if you've worked previously relying solely on Microsoft products and graphical UIs. It starts from the Linux/UNIX basics but boils down to the fact that you have to be comfortable with command line tools. And no, experience in PowerShell scripting doesn't help that much. Best way is to learn by doing.

First time I had to face Linux in my working career was in a project where we used IaaS services from AWS for hosting a .NET based web application. You might be thinking where do you need Linux in this picture? Well, I learned that you can't get around it for things like _load balancing_, _ssl certificates_ and _bastion hosts_ to start with.

And it doesn't stop there. Container technologies like _Docker_ and _Kubernetes, _CLI tools for public cloud platforms_, _test automation_, the whole _front-end development ecosystem_.. Modern software development is cross-platform nowadays.

## Docker for Windows

Using Docker properly on Windows became possible just a few years ago along with Windows Server 2016 and Windows 10. In the OS world Docker and containers have been mainstream for much longer. It's actually easier to start from Linux based containers because the Windows based container technology has still a few flaws. Containers are used for pretty much everything from running builds and development environments all the way to production.

I use Windows 10 Pro and Dell XPS 13 9370. The Windows Home Edition is not enough since it lacks support for Hyper-V. Docker for Windows _Community Edition_ includes everything you need for working with Docker based containers. The Docker community provides very good instructions on [getting started with Docker for Windows](https://docs.docker.com/docker-for-windows/). As you start working with real projects you want to adjust some of the settings like allocating more memory and CPU for the Docker daemon - which is actually a Linux based VM run on top of your machine's Hyper-V called `MobyLinuxVM`.

### Docker volume share

One of the first things you will most likely want to get working after setting up Docker on your machine is to configure the volume sharing between your host machine and Docker. There are plenty of instructions for this in the internet and I've tried many of those. But since Windows 10 seems to get feature updates quite frequently there was always some issues, nothing seemed to work. Maybe you're luckier than me but during my attempts I managed to break my Docker Virtual Network Adapter beyond repair and had to even restore the laptop to factory settings once. Don't make the same mistake!

It was honestly one of those moments:

{% raw %}

<div style='position:relative; padding-bottom:calc(55.00% + 44px)'><iframe src='https://gfycat.com/ifr/ImperturbableGleamingHuman' frameborder='0' scrolling='no' width='100%' height='100%' style='position:absolute;top:0;left:0;' allowfullscreen></iframe></div>

{% endraw %}

I managed to get it working in the end though with the help of [this blog post](https://nickjanetakis.com/blog/setting-up-docker-for-windows-and-wsl-to-work-flawlessly).

The breakthrough for me was to modify the `wsl.conf` like so

```conf
sudo nano /etc/wsl.conf

[automount]
root = /
```

### Linux subsystem aka WSL

Having **Docker for Windows** installed on your machine enables you to run containers (both Linux and Windows based) just fine. But as you go through some Dockerfile examples and start experimenting with Linux based containers you'll notice that having a genuine `bash` would be awesome. Luckily Microsoft provides the `Linux subsystem` (WSL) out-of-the-box which can be enabled from under _Windows Features_. Next you'll want to install _Ubuntu_ app from Microsoft Store and configure it to use and there you go. Good instructions can be [found from here](https://nickjanetakis.com/blog/using-wsl-and-mobaxterm-to-create-a-linux-dev-environment-on-windows).

**WSL** is a really powerful tool which enables you to work seamlessly with Linux - natively from within your host machine. You'll also want to install Docker there but connect to the daemon on the host machine to enable running Docker from both. Coupled with the volume share you have a full blown, Linux native development environment within your Windows. Helps a lot when you need to work with different scripting languages for instance.

Here's couple of additional tricks I found useful myself

* [Linking to your host machine's SSH keys from WSL](https://florianbrinkmann.com/en/3436/ssh-key-and-the-windows-subsystem-for-linux/)
* [Enabling npm in WSL](https://blur.kr/2018/06/19/Resolve-npm-command-issue-on-WSL/)
* [Case-sensitivity for volume mounts in WSL](https://blogs.msdn.microsoft.com/commandline/2018/06/14/improved-per-directory-case-sensitivity-support-in-wsl/)

### What's next

Having these tools in place is a real productivity boost for Windows users taking the leap into cross-platform development. But why settle for just `bash` when you can have **VSCode** - the ultimate IDE that works seamlessly from every developer's machine?

I will cover this in more detail in my next blog post where you'll see how well **WSL** and **Docker** integrate with **VSCode**.
