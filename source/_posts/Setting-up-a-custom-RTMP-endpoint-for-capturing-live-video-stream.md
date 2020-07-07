---
layout: photo
title: Setting up a custom RTMP endpoint for capturing live video stream
tags:
  - Node Media Server
  - Azure Container Instances
  - Azure Storage
  - Azure CLI
  - OBS Studio
  - Node.JS
photos:
  - /images/photos/custom-rtmp-for-live-streaming.jpg
categories:
  - Azure
  - Docker
  - Live streaming
date: 2020-07-07 10:17:37
---



Hosting your own RTMP endpoint through a Docker container in public cloud. I'll show you how to get started.

<!-- more -->

## Taking a hobby to the next level

Live streaming has become way more common these days when most of us "digital workers" have switched to remote-only mode and everything happens virtual. I did my first (ever) live stream this spring as part of the [Global Azure Virtual 2020](https://virtual.globalazure.net/) virtual event. It really pushed me to figure out the practicalities around hosting a live stream and delivering it successfully. Preparation really is the key there and testing out things before hand is a must. I can really recommend trying it out - you will get out of your comfort zone for sure!

Streaming the live video happened over a built-in RTMP endpoint in YouTube. This intrigued me to find out more about the subject. I have a special interest in video techniques, what can I say.

So I have this commercial drone from DJI - the [Mavic 2 Pro](https://www.dji.com/mavic-2). It's pretty amazing, supports 4K video and has tons of features to choose from. I've been learning how to use it for over a year now, starting from the very basics and diving more deep into customizing the camera settings for different lighting conditions and learning away from the auto focus. 

Going through the menus and settings in the _DJI GO 4_ app I couldn't help noticing the section under General Settings where it says **Choose Live Streaming Platform**

{% asset_img dji-go-general-settings.jpg General Settings in DJI GO 4 app %}

When you navigate further in the app it shows you the different options for live streaming

{% asset_img dji-go-live-stream-options.jpg Live streaming options in DJI GO 4 app %}

Finally, when you choose the **Custom RMTP** option, it asks you for the RMTP endpoint URL for ingesting the live stream

{% asset_img dji-go-custom-rtmp-url.jpg Custom RTMP option in DJI GO 4 app %}

How can an engineer resist a challenge like this? I know I couldn't :)

## Node Media Server

{% blockquote %}
The first question you should be asking yourself at this point: Why self-host when there's plenty of services that can do it for you? 
{% endblockquote %}

My arguments were

- Better control over the stream
- Making the stream private
- It's more fun to build it yourself

I started to look for different options in the field. Most common approach people were using was to setup Media Streaming Server on top of NGinx. It seemed a little complex for my needs and I wanted to be able to customize the logic if needed. Plus I didn't like the fact it required introducting NGinx. Then I found this [Node Media Server](https://github.com/illuspas/Node-Media-Server) from GitHub and was sold. It was simple to configure and runs on Node.js.

Node Media Server can do a whole lot of other things as well but I'm concentrating here on a couple its features in particular since I needed it to consume a **single live stream**

1. RTMP endpoint
2. Video recording
3. Authentication

{% blockquote %}
To get started, fork (or download directly) the source code from https://github.com/illuspas/Node-Media-Server and edit the configs directly in `app.js`.
{% endblockquote %}

Minimum config for NMS to host RTMP endpoint is as follows

```json
const config = {
  rtmp: {
    port: 1935,
    chunk_size: 60000,
    gop_cache: true,
    ping: 30,
    ping_timeout: 60
  },
  http: {
    port: 8000,
    allow_origin: '*'
  }
};
```

The http port is used for Web Admin Panel. The version of NMS (v2.1.8) I was using didn't support disabling it.

### Using ffmpeg to capture video recordings

One of the libraries Node Media Server (NMS) utilizes under the hood is [ffmpeg](https://ffmpeg.org/). For me this was the single most important thing to get right because it's responsible for generating the video record (MP4) from the stream.

To get the best quality for my use case I used the following settings

```json
const config = {
  trans: {
    ffmpeg: FfmpegPath,
    tasks: [
      {
        app: 'live',
        vc: "copy",
        vcParam: ['-preset', 'slow', '-crf', '22'],
        mp4: true,
        mp4Flags: '[movflags=faststart]',
      }
    ]
  }
};
```

You can check more info on the FFmpeg's H.264 Video Encoding settings [from here](https://trac.ffmpeg.org/wiki/Encode/H.264). 

### Applying authentication

{% blockquote %}
You can skip this part if you're okay with exposing your RTMP endpoint to the public.
{% endblockquote %}

I wanted to make the live stream private. I wasn't planning to broadcast through the RTMP endpoint. I simply wanted it to consume the live video stream from my drone and record it as MP4 for backup and other purposes. Also, I didn't want others connecting to it in the cloud to ensure it runs smoothly and without interruptions. 

NMS supports authentication out-of-the-box but few steps are required:

1. Configure authentication on along with **your secret**

```json
const config = {
  auth: {
    play: true,
    publish: true,
    secret: '<yoursecret>'
  }
};
```

2. Define length for your token's **expiration time** and the **name of your stream**

    Easiest way to do this is to create a JavaScript file (eg. `genAuthToken.js`) and then execute it to generate the token

```bash
$ cat <<EOF > genAuthToken.js
const md5 = require('crypto').createHash('md5');
let key = '<yoursecret>';
// timestamp of the expiration time in future
let exp = (Date.now() / 1000 | 0) + <arbitrary number of seconds>;
let streamId = '/live/<nameofyourstream>';
console.log(exp+'-'+md5.update(streamId+'-'+exp+'-'+key).digest('hex'));
EOF

$ node genAuthToken.js
```

3. Generate the **final url** for the rtmp endpoint

```
rtmp://<endpointaddress>/live/<nameofyourstream>?sign=<token>
```

Couple of notes
- The **sign** keyword can not be modified
- This process is done **per RTMP endpoint**

### Adding support for environment variables

Having to hardcode configuration values that are most likely to change per environment is never a good idea.

Let's change the `mediaroot` and `secret` configs to read their values from environment variables by making the following changes to `app.js`

```JavaScript
const MediaRoot = process.env.MEDIA_ROOT || './media'

const config = {
  ..
  http: {
    port: 8000,
    mediaroot: MediaRoot,
    allow_origin: '*'
  },
  ..
  auth: {
    play: true,
    publish: true,
    secret: process.env.AUTH_SECRET
  }
};
```

### Containerizing the NMS

Node.js apps are a perfect target for Docker containers. There was already [a sample Dockerfile](https://github.com/illuspas/Node-Media-Server/blob/master/Dockerfile) available in the repo but it was outdated and didn't really work.

After some modifications [my version of the Dockerfile](https://github.com/Masahigo/Node-Media-Server/blob/master/Dockerfile) looked like this

```Dockerfile
FROM node:10.20.1-alpine as install-npm

RUN mkdir -p /app
WORKDIR /app

# install deps
COPY package*.json /app/
RUN npm install

FROM node:10.20.1-alpine

RUN apk update && \
    apk upgrade && \
    apk add 'ffmpeg>4.0.0'

RUN mkdir -p /app
WORKDIR /app

ARG NODE_ENV=production
ENV NODE_ENV=${NODE_ENV}

ENV MEDIA_ROOT='./media' FFMPEG_PATH='/usr/bin/ffmpeg'

# Copy deps
COPY --from=install-npm /app/node_modules /app/node_modules
# Setup workdir
COPY . /app

EXPOSE 1935

CMD ["node","app.js"]
```

Some take aways from this

- NMS requires `ffmpeg` version 4 or newer to function
- Use production mode in Node.js app to optimize performance
- Multistage build minimizes the image size
- No need to expose port for HTTP server

Build and push your version of the nms container image to [DockerHub](https://hub.docker.com/). You can find detailed instructions [here](https://github.com/Masahigo/Node-Media-Server/blob/master/readme-azure-docker.md#building-and-testing-image).

## Hosting the NMS in a container

{% blockquote %}
Up until this point there has been nothing specific to the hosting environment apart from Docker.
{% endblockquote %}

You could, in theory at least, host the NMS as a serverless application. I like to keep my options open though, and going with serverless usually means locking yourself to the hosting platform more tightly. Plus this type of workload where I expect a steady load and long processing times is not ideal for it.

I'm using Azure for hosting the RTMP endpoint mainly because I have some other services running there that will do some post-processing for the video recordings. Azure provides several different services to choose from for running container workloads. The simplest one is Azure Container Instances (ACI) and I went with that.

### Azure Container Instances

ACI has been around for a long time in Azure already and is quite mature service for this type of use case. Although MS seems to be shifting focus more to Web Apps for Containers nowadays there is still active development put into it. If you need to run a single container workload in Azure without the need for hybrid connectivity this is your go-to service.

The way the service works is you define the compute resources, ports and settings that your app requires and where to pull the container image from. Based on these specs ACI spins up your container and keeps it running. If you need to change any of these specs later on you terminate the instance and deploy a new one to replace it. If you've messed up something (like forget to inject environment variable that your app relies on) the runtime will try to initialize your app in a container for several times but will eventually stop trying when it detects the app is not stable to be exposed to outside world.

### Persisting video recordings

Due to the nature of containers you cannot rely on their state. Containers (and ACI) are stateless.

ACI supports [mounting an Azure file share](https://docs.microsoft.com/en-us/azure/container-instances/container-instances-volume-azure-files) for persisting data. I hadn't tried this out before but it worked like a charm.

Once you have your [resource group](https://docs.microsoft.com/en-us/cli/azure/group?view=azure-cli-latest#az-group-create-examples) created, just run these commands from the [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)

```bash
# Change these four parameters as needed
ACI_PERS_RESOURCE_GROUP=MyResourceGroup
ACI_PERS_STORAGE_ACCOUNT_NAME=mystorageaccount$RANDOM
ACI_PERS_LOCATION=westeurope
ACI_PERS_SHARE_NAME=acishare

# Create the storage account with the parameters
az storage account create \
    --resource-group $ACI_PERS_RESOURCE_GROUP \
    --name $ACI_PERS_STORAGE_ACCOUNT_NAME \
    --location $ACI_PERS_LOCATION \
    --sku Standard_LRS

# Create the file share
az storage share create \
  --name $ACI_PERS_SHARE_NAME \
  --account-name $ACI_PERS_STORAGE_ACCOUNT_NAME

# Grab credentials (ACI_PERS_STORAGE_ACCOUNT_NAME, STORAGE_KEY) needed later on
echo $ACI_PERS_STORAGE_ACCOUNT_NAME
STORAGE_KEY=$(az storage account keys list --resource-group $ACI_PERS_RESOURCE_GROUP --account-name $ACI_PERS_STORAGE_ACCOUNT_NAME --query "[0].value" --output tsv)
echo $STORAGE_KEY
```

_Your file share should look similar to this in Azure portal_

{% asset_img storage-aci-file-share.png Azure file share for ACI %}

Then when you deploy the app to ACI just map the volume mount path with same value as NMS's media root (eg. `/aci/media/`) and provide the credentials from previous step and it will just work.

### Deployment using Azure CLI

ACI supports defining your app's deployment in [YAML format](https://docs.microsoft.com/en-us/azure/container-instances/container-instances-reference-yaml).

Here's an example of what it would look like at this point

```yml
#node-media-server.yml
apiVersion: 2018-10-01
location: westeurope
name: node-media-server
properties:
  containers:
  - name: node-media-server
    properties:
      environmentVariables:
        - name: 'MEDIA_ROOT'
          value: '/aci/media'
        - name: 'AUTH_SECRET'
          secureValue: '<yoursecret>'
      image: <your account in DockerHub>/node-media-server:latest
      ports:
        - port: 1935
      resources:
        requests:
          cpu: 1.0
          memoryInGB: 1.5
      volumeMounts:
      - mountPath: /aci/media/
        name: filesharevolume
  osType: Linux
  restartPolicy: Always
  ipAddress:
    type: Public
    dnsNameLabel: my-custom-rtmp #this must be unique in azure region
    ports:
    - protocol: tcp
      port: '1935'
  volumes:
  - name: filesharevolume
    azureFile:
      sharename: acishare
      storageAccountName: <ACI_PERS_STORAGE_ACCOUNT_NAME>
      storageAccountKey: <STORAGE_KEY>
tags: null
type: Microsoft.ContainerInstance/containerGroups
```

Deploying ACI using the template is straightforward with Azure CLI

```bash
# Use same resource group name as in previous step
RESOURCE_GROUP_NAME=MyResourceGroup
az container create --resource-group $RESOURCE_GROUP_NAME -f node-media-server.yml

# Get the ACI's address info after deployment
az container show -g $RESOURCE_GROUP_NAME -n node-media-server --query ipAddress
```

_Your ACI should look similar to this in Azure portal_

{% asset_img aci-nms-overview.png ACI container overview %}

_If everything is running ok the logs show this_

{% asset_img aci-nms-logs.png ACI container logs %}

## Live streaming to your RTMP endpoint

You've made it this far, hurray! Now to the fun part.

{% raw %}
<div style="width:100%;height:0;padding-bottom:75%;position:relative;"><iframe src="https://giphy.com/embed/1qa9CGDeuEN2w" width="100%" height="100%" style="position:absolute" frameBorder="0" class="giphy-embed" allowFullScreen></iframe></div><p><a href="https://giphy.com/gifs/having-fun-1qa9CGDeuEN2w">via GIPHY</a></p>
{% endraw %}

### Testing locally from OBS Studio

One of the take aways from my first live stream experience was introducing myself into a tool called [OBS Studio](https://obsproject.com/): a free and open source software for video recording and live streaming. It's an excellent tool for creating professional live streams for different use cases, and as it turns out, for testing RTMP endpoints as well.

I'm showing here how to test against the RTMP endpoint hosted in Azure directly.

- Grab the **final url** from earlier chapter (2.2). 
  * If you haven't configured authentication to your RTMP endpoint then you can just omit the `?sign=<token>` part from the url.
- Replace the `<endpointaddress>` part with the fqdn from your ACI
  * You can find the referenced `genObsAuth.js` file [from here](https://github.com/Masahigo/Node-Media-Server/blob/master/deployment/genObsAuth.js)

```bash
# Get RTMP endpoint address
az container show -g $RESOURCE_GROUP_NAME -n node-media-server --query ipAddress.fqdn -o tsv
# Generate new token - just make sure to substitute 'replaceme' in the file with '<yoursecret>' before running the command
node deployment/genObsAuth.js 
```

**Complete url** to be used for testing from OBS Studio looks something similar to this: 
`rtmp://my-custom-rtmp.westeurope.azurecontainer.io/live/obs?sign=1595046544-bedf34dad9da573e43d709084078bd72`

1. Open OBS Studio
2. Follow [these instructions](https://streamshark.io/obs-guide/adding-webcam) for adding a _Scene_ and _Video Capture Device_ using your webcam
3. Verify that your video input is working

{% asset_img obs-studio-testing-live-stream.png Testing video input in OBS Studio %}

4. Navigate to: _Settings_ > **Stream**
5. Fill in the stream details
- **Service**: `Custom`
- **Server**: `rtmp://<endpointaddress>/live`
- **Stream Key**: `obs?sign=<token>`

{% asset_img obs-studio-stream-settings.png Configuring stream settings in OBS Studio %}

6. **Apply** + **OK**
7. Press **Start Streaming**
8. Wait for a second or two - if all goes well you'll see the stream being broadcasted

{% asset_img obs-studio-live-streaming.png Live streaming from OBS Studio to the custom RTMP endpoint %}

9. Let the stream run for a while and then press **Stop Streaming**
10. Check the logs from the ACI container instance. You should see new events logged there, eg

```
# Event in Node Media Server about converting the stream to MP4 after it was stopped
# Files are named using timestamps
[Transmuxing MP4] /live/obs to /aci/media/live/obs/2020-07-06-15-06.mp4
```

### Sending actual drone footage

The process from DJI drone is very similar. Biggest difference is that you need to provide the **Complete url** in the Custom RTMP setting - which was sort of split into two parts when testing from OBS Studio.

1. Substitute `<yoursecret>` in `genAuthToken.js` with your own to generate `<token>`

```bash
$ cat <<EOF > genAuthToken.js
const md5 = require('crypto').createHash('md5');
let key = '<yoursecret>';
let exp = (Date.now() / 1000 | 0) + 999999999999;
let streamId = '/live/dji';
console.log(exp+'-'+md5.update(streamId+'-'+exp+'-'+key).digest('hex'));
EOF

$ node genAuthToken.js
```

2. Compose your **Complete url** substituting `<token>` with the one generated in previous step and transfer it to your mobile phone in a secure way
  - `rtmp://my-custom-rtmp.westeurope.azurecontainer.io/live/dji?sign=<token>`
3. Power up the drone and your remote controller + attach mobile phone to the controller
4. Start the _DJI 4 GO_ app
5. Adjust the video settings for live streaming
  - **Video Format**: `MP4`
  - **Color**: `None`
  - **Encoding Format**: `H.264`

{% asset_img dji-settings-video-general.jpg DJI Drone video settings general %}

  - **Video Size**: `4K/HQ 24fps`

{% asset_img dji-settings-video-size.jpg DJI Drone video size %}

6. Navigate to Custom RTMP setting
  - General Settings > Choose Live Streaming Platform > Custom
7. Enter your **Complete url** (see step 2)
8. Press **Next**
9. Press **Start**
10. Wait for a second or two and check from _DJI 4 GO's_ upper left corner the stream's status (Live Streaming), you should see the amount of seconds it has been broadcasting

{% asset_img dji-live-streaming.jpg DJI Drone live stream being broadcasted %}

11. Press the broadcasting icon to enter the status screen and press **End Livestreaming**

{% asset_img dji-end-live-streaming.jpg DJI Drone live stream status %}

12. Press **Yes** to exit the live streaming screen

Finally, you can download the MP4 from Azure storage and check the end result

- Navigate to your Storage account in Azure portal
- Download the MP4 file with the latest date and open in video player

{% asset_img mp4-video-recording.png Playing MP4 video record streamed from DJI drone %}
