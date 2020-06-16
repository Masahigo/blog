---
title: WSL 2 is finally official!
tags:
  - Windows 10
  - WSL
  - Git
  - SSH
photos:
  - /images/photos/wsl-2.jpg
categories:
  - Linux
  - Cross-platform development
date: 2020-06-16 13:16:47
---


The next generation of Windows Subsystem For Linux (WSL) is included as part of Windows 10's latest feature update 2004.

<!-- more -->

## What's all the fuss about

Having worked using the first version of WSL in several projects within the past 1,5 years I had been already waiting to transition to its next generation. The only thing holding me back for so long (WSL 2 has been in preview for quite some time) had been the fact it required extra effort to get it installed, joining the _Windows Insider Program_ and what not. I wanted to wait until it's stable enough for Microsoft to distribute it as part of a regular _Windows Update_. 

The day finally arrived.

{% raw %}
<div style="width:100%;height:0;padding-bottom:83%;position:relative;">
<iframe src="https://giphy.com/embed/mGK1g88HZRa2FlKGbz" width="100%" height="100%" style="position:absolute" frameBorder="0" class="giphy-embed" allowFullScreen></iframe></div>
<p><a href="https://giphy.com/gifs/Friends-episode-1-season-9-friends-tv-mGK1g88HZRa2FlKGbz">via GIPHY</a></p>
{% endraw %}

If you've ever tried using WSL in some real projects, you've probably noticed it can be painfully slow. Building a bigger Docker image or installing npm packages can take ages. For this kind of reasons, I've actually started to avoid working from WSL when I can. But with WSL 2 I don't have to anymore.

The next generation of WSL seems to deliver on its promise.

## Upgrading to WSL 2 on Windows 10

The [latest Feature update for Windows 10 (version 2004)](https://docs.microsoft.com/en-us/windows/whats-new/whats-new-windows-10-version-2004) was published last week.

To get started, open Windows Update and proceed to install it. It takes around 5-10 minutes after the reboot for the installation to finish.

WSL 2 is not automatically enabled, there are some extra steps involved in taking it into use. I noticed this when I tried to set my default WSL version to 2 after the Feature update:

```cmd
C:\>wsl --set-default-version 2
WSL requires an update to its kernel component. For more information please visit https://aka.ms/wsl2kernel
```

Go ahead and proceed with the manual update of the Linux kernel (x64). 

If you have Docker for Windows Desktop installed, it will inform you about the WSL 2 Backend initialization

{% asset_img docker-for-win-desktop-wsl-2.png Win 10 notification for WSL 2 backend %}

Last but not least, make sure the Linux distro installed and used through WSL is using version 2. For instance, I had `Ubuntu` still running on WSL 1 at this point. It's possible to convert the existing Linux distro to use WSL 2 but I decided to uninstall it completely and replace it with a fresh installation of `Ubuntu` from the Windows Store. Since WSL 2 was set as the default version it picked that instead now. You can find more details on this topic [from here](https://scotch.io/bar-talk/trying-the-new-wsl-2-its-fast-windows-subsystem-for-linux).

You should now have your Linux distro running via WSL 2:

```cmd
C:\>wsl -l -v
  NAME                   STATE           VERSION
* Ubuntu                 Running         2
  docker-desktop         Running         2
  docker-desktop-data    Running         2
```

## Keep those file systems separated

One of the things I loved about when working from WSL 1 was the sharing of file systems. One concrete example is to utilize the same SSH keys you've set up on the Windows side - you could just point to those from WSL using symlinks.

{% blockquote %}
With WSL 2 the Linux distro sees itself as it's own operating system. Ultimately you need separate SSH keys for Linux in WSL 2.
{% endblockquote %}

This leads also to a bigger question: _Should I just separate the file systems altogether?_ **I think you should.**

My approach was to create a folder called `/repos` under the root of my `/home` folder in Linux. Then I'm planning to create separate subfolders under there for different client projects. 

For my personal projects (like this blog) the folder structure looks like this:

```bash
/home$ find ./repos/ -mindepth 1 -maxdepth 2 -type d
./repos/personal
./repos/personal/dev-playground
./repos/personal/video-indexer
./repos/personal/blog
```

An important thing to note here is granting your own user account permissions to these subfolders **located under the root home directory**:

```bash
/home$ sudo mkdir repos
/home$ sudo chown -R $USER repos
```

## Git, SSH keys and file permissions

It's so easy to `sudo` your way around with Linux. When I was setting up Git and SSH keys for my new WSL 2 installation I learned why I shouldn't be doing that.

First thing I did was to copy my current SSH keys from Windows to Linux:

```bash
 $ cd $HOME
~$ mkdir .ssh
~$ cp -r /mnt/c/Users/masim/.ssh/. ~/.ssh/
```

After this set the proper Linux file permissions:

```bash
~$ chmod 600 ~/.ssh/id_rsa
~$ chmod 600 ~/.ssh/github_rsa
~$ chmod 600 ~/.ssh/config
```

Using `config` file helps in managing SSH keys for different Git hosts, eg for Github

```
Host github.com
    Hostname github.com
    User git
    IdentityFile ~/.ssh/github_rsa
```

Make sure to also include this in your `~/.gitconfig`

```
[core]
        sshCommand = "ssh -F ~/.ssh/config"
```

**Notice how I'm not using `sudo` here?** There is a reason for that.

I was struggling with getting ssh agent working in WSL 2. The issues were caused by the fact that the file permissions were tied to `sudo` user, not my own user account. 

Now you should be able to complete also these steps (Ubuntu)

1) Install [keychain](https://www.funtoo.org/Keychain)

```bash
sudo apt install keychain
```

2) Add the following line at the end of your `~/.bashrc`

```
eval ``keychain --eval --agents ssh id_rsa
```

3) Restart your terminal session and behold

{% asset_img wsl2-keychain.png WSL 2 Keychain in Windows Terminal %}

## Additional resources

- [Moving Your JavaScript Development To Bash On Windows](https://www.smashingmagazine.com/2019/09/moving-javascript-development-bash-windows/)
- [Sharing SSH keys between Windows and WSL 2](https://devblogs.microsoft.com/commandline/sharing-ssh-keys-between-windows-and-wsl-2/)
- [Set up your Node.js development environment with WSL 2](https://docs.microsoft.com/en-us/windows/nodejs/setup-on-wsl2)
