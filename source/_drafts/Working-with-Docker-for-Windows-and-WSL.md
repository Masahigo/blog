---
layout: photo
photos:
 - images/docker-for-windows.jpg
title: Working with Docker for Windows and WSL
categories:
- Docker
- Linux
tags:
- Docker for Windows
- WSL
- Cross-platform development
- VSCode
---

Being a .NET developer in today's world requires more than just understanding the MS tech stack. OS based technologies have become defacto in many areas of software development. Microsoft is embracing the change and so should you.

<!-- more -->

## Words of motivation

There is a certain learning curve when it comes to adopting OS technologies. Especially if you've worked previously relying on Microsoft products and graphical UIs only. It starts from the Linux basics but boils down to the fact that you have to be comfortable with command line tools. And no, experience in PowerShell scripting doesn't help that much. Best way is to learn by doing.

First time I had to face Linux in my working career was in a project where we used IaaS services from AWS for hosting a .NET based software. You might be thinking where do you need Linux in this picture? Well, I learned that you can't get around it for things like _load balancing_, _ssl certificates_ and _bastion hosts_ to start with. Also container technologies like _Docker_ and _CLI tools for public cloud platforms_ demand it. Not to mention where the whole front-end development ecosystem is going. Modern software development means going cross-platform, period.

I'm not a Linux expert but I've learned a thing or two and I'd like to share them with you.

## Docker for Windows

Using Docker properly on Windows became possible just a few years ago with Windows Server 2016 and Windows 10. In the OS world Docker and containers have been mainstream for much longer. It's actually easier to start from Linux based containers because the Windows based container technology has still a few flaws. Containers are used for pretty much everything from running builds and development environments all the way to production.

I use Windows 10 Pro and Dell XPS 13 9370. The Windows Home Edition is not enough since it lacks support for Hyper-V. You can get around it but I don't recommend going that path. Docker for Windows _Community Edition_ includes everything you need for working with Docker based containers. As you start working with real projects you want to adjust some of the settings like allocating more memory and CPU for the Docker daemon - which is actually a Linux based VM run on top of your machine's Hyper-V called `MobyLinuxVM`.
