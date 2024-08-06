---
title: Reddit Video Downloader
description: A small WabApp to to find the video and audio files of a Reddit post, download them, sync them and generate a new downloadlink. 
date: '2021-12-24'
pic: '/img/blog/reddvid_small.png'
tags: ['Python', 'Reddit', 'Flask', 'ffmpeg', 'API', 'VUE']
---

# One Day Build: WebApp to download Videos from Reddit 
---
It has become kind of annoying to download a simple video from Reddit. My sister wanted to save a video but couldn't do it. So, I did what all programmers do - I wrote a small app.  
You can try it out [here](https://reddvid.netlify.app/) or use it via your terminal like described *below*.
![Pic](/img/blog/reddvid_small.png)

## Some Background
The URLs of videos on Reddit are not directly visible. You have dig through some HTML tags and even more annoying, Reddit sores to video and audio files separably. So we need to find the URLs, download the content and combine video and audio. For this I wrote a small Python backend.  

### The Backend
The backend requires a URL as an argument, and makes a request to that URL. The result is analyzed with [`BeautifulSoup`](https://www.crummy.com/software/BeautifulSoup/bs4/doc/). After the video and audio URL got extracted, both files are downloaded separably and are then combined with [`ffmpeg`](https://ffmpeg.org/). 
I used Flask to handle the HTTP requests and provide routing. It is a simple-to-use minimal framework that was fast to implement.  
I wanted people to be able to use the backend directly, so it is possible to download videos with a terminal. The following bash function should download any Reddit video for you without the need to use any browser:
```bash
# Add this function to yor terminal session - or put it into your .bash_rc
# This need wget, curl and jq
reddvid () {
    wget https://reddvid.herokuapp.com/$(curl -X GET 'https://reddvid.herokuapp.com/' --form "url=\"${1}\"}"  | jq -r '.download')
}
# Call the function
reddvid <REDDIT_URL>
```

Any non-technical person has the option to use the WebApp frontend. 
### The Frontend
The WebApp is a simple VUE app that was build with nuxt.js, simply because I already know VUE and I like my WebApps to be a static page that can be served by any HTTP-Server. This allows for a broad range of deployment options.  

### Deployment
The deployment strategy I chose was only based on tractability and cheep criteria. I am a student that did this project for fun and did not and couldn't spend much on server infrastructure. The backend is deployed via a [Python Docker Image](https://hub.docker.com/r/hegerdes/reddvid) on [Heroku](https://heroku.com/) with a deployment option that goes to sleep after 30 min. The WebApp is hosted on [Netlify](https://www.netlify.com/) which is a cheap option for static apps that creates a new deployment for every commit.
## Have Fun
This is a project I build for my own usage and without much testing. I'm sure it has bugs and that it will beak on specific actions. Just use it if it is handy to you, share your thoughts, encountered issues and possible improvements. Swarm knowledge is the bast way to learn!!! 

**See you!**
