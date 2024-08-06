---
title: Dockerfile for NodeJS & Typescript
description: Learn the best practices on how to bundle a TypeScript project for production with Docker. Get insights about Dockers overlay filesystem for small and secure builds. 
date: '2021-11-15'
pic: '/img/blog/docker.png'
tags: ['Docker', 'NodeJS', 'JavaScript', 'TypeScript']
---

# How to build a Docker image for a TypeScript based NodeJS project
---
You just finished your TypeScript project and now you want to release it to the internet by using ECS, GKE, Azure or any other cloud service? Or maybe you just want to share it with your co-workers without having them to install and configure additional software. Docker is a great use case for this!

This post shows demonstrates how to create an optimized production ready Docker image for your project.
![pic](/img/blog/docker.jpg)


## Pre-Requirements
In order to build a Docker image you must have access to system that has the Docker engine installed. Depending on your system you need one of the following:

| Host    | Version        | Link         |
|---------|----------------|--------------|
| Linux   | docker-ce      | [Download](https://docs.docker.com/engine/install/debian/)     |
| Windows | Docker Desktop | [Download](https://docs.docker.com/desktop/windows/install/)   |
| MacOS   | Docker Desktop | [Download](https://docs.docker.com/desktop/mac/install/)       |

*Note:* Docker builds upon functions provided by the Linux kernel. Windows and macOS need to virtualize the kernel. Therefore, the best performance is achievable on linux.

## Project setup
Assuming the following file structure:
```
project/
  - src/
      - server.ts
      - util.ts
  - node_modules
  - index.ts
  - tsconfig.json
  - package.json
```

In order to run our app we need to:

 1. Install our dependencies
 2. Transpile TS to JS
 3. Start our app

This needs to be specified in our Dockerfile which acts as the build instructions for our Docker image. We create a file named Dockerfile and add the following:

```Dockerfile
FROM node

WORKDIR /app
COPY . /app
RUN npm install && npm build
```
Our image is based on the official NodeJS Docker image. We copy our source code into the image and run the install and compile command.

This would work but is not an optimal solution. We are using Docker to get a consistent runtime that works everywhere but by not using a specific tag for our base image we are losing the consistence. If no tag is specified the `latest` tag is used which changes often.

A lot of images include a lot of software that we actually do not need. These increases image size, storage consumption and network transfer times. It also increases to attack surface because any other program can have additional vulnerabilities. Let's fix some of this:

```Dockerfile
FROM node:16-alpine

WORKDIR /app
COPY package.json package-lock.json /app/
RUN npm install

COPY . /app
RUN npm run build
```

Now we are using an exact version and the much smaller alpine version of Nodes Docker image. We are also utilizing Dockers caching functionality. Docker only runs the commands that changed since the last run. Since we are not modifying the `package.json` as often as our source code we can cache the install command and save time. This is better but not perfect yet. In order to run our app we neither need the TypeScript files nor the `tsc` compiler.

This is where multi-stage build come handy. We can build our JavaScript in one stage and then copy the result to another stage that is actually used.

``` Dockerfile
FROM node:16-alpine as build

WORKDIR /app
COPY package.json package-lock.json /app/
RUN npm install

COPY . /app
RUN npm run generate

FROM node:16-alpine as production

USER node
WORKDIR /app
COPY --chown=node:node --from=build /app/compiledJS /app
RUN npm install --only=production
```

Now the code is compiled in one stage and shipped in another. We are also changing to user in order to omit running our app as root. Lower privileges are another step to increase your app's security.

To increase the flexibility of our Dockerfile we can add arguments. With arguments, we can influence the building process on execution without modifying the Dockerfile. A common argument is the `VARIANT` variable. Which allows to change the version of our base image.

The last step is to include an `ENTRYPOINT` to specify what command should be executed when a container is created. I strongly recommend to directly call `node index.js` instead of using `npm start`. When using `npm`, npm becomes our main process and acts as a process manager for the node process. Unfortunate `npm` performs poorly as a process manager. It does not redirect any control or exit signals to the main node process. This can lead to a container not willing to stop or an unexpected shutdown of our node process without properly handling exit tasks.

The final Dockerfile should look something like this:
``` Dockerfile
FROM node:16-alpine as build

WORKDIR /app
COPY package.json package-lock.json /app/
RUN npm install

COPY . /app
RUN npm run generate

ARG VARIANT=16-alpine
FROM node:${VARIANT} as production

USER node
WORKDIR /app
COPY --chown=node:node --from=build /app/compiledJS /app
RUN npm install --only=production

ARG COMMIT_TAG="none"
LABEL COMMIT_TAG=$COMMIT_TAG
ENTRYPOINT [ "node" , "index,js"]
```


We now can build our image with:  
`docker build -t my-app --build-arg COMMIT_TAG="version-1.0.0" .`
