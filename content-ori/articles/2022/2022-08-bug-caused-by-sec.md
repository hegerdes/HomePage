---
title: Broken NodeJS Apps due to secerity dot-release - Debugging the NodeJS CVE-2022-32213 fix 
description: When none of your code works anymore due to a to a innocuous secrity fix in a dot release you need some quality time with your rubber duck to find the root cause.
date: '2022-08-18'
pic: '/img/blog/nodejs-header-square.png'
tags: ['NodeJS', 'Work', 'Bug', 'debugging', 'CVE', nginx]
---

# Broken NodeJS Apps due to security dot-release
---
On July 7th the vulnerabilities [CVE-2022-32213](https://cve.report/CVE-2022-32213), [CVE-2022-32214](https://cve.report/CVE-2022-32214) and [CVE-2022-32215](https://cve.report/CVE-2022-32215) where publicly disclosed. They affected all current NodeJS versions (v14.x, v16.x, v18.x)! The same day fixes for the vulnerabilities where released. My colleagues and I assumed a quick and easy deployment to spit these fixes onto our client's production systems. A simple rebuild of the old code state with the new NodeJS version and replacement of the old containers. We thought wrong! 🙃

Our staging system showed that some of our apps didn't get any requests anymore and clients got a HTTP 4xx error code.
![VSCode](/img/blog/nodejs-header.png)


---
### Some Background Information
For a better understanding let me give a simplified overview of our system architecture:
![ReverseProxy](https://upload.wikimedia.org/wikipedia/commons/thumb/6/67/Reverse_proxy_h2g2bob.svg/1200px-Reverse_proxy_h2g2bob.svg.png)

We use a reverse proxy which is the only service directly exposed to the internet. It handles TLS termination and routes the traffic to the appropriate backend service. Some services require TLS client verification ([mTLS](https://www.cloudflare.com/learning/access-management/what-is-mutual-tls/)), meaning the client has to send its unique certificate to the server where it gets verified and passed to the backend service if the certificate was valid.

We triggered a new build with the updated NodeJS version (in our case form NodeJS v14.19.3 to v14.20.0) and deployed it to our testing system. The deployment went smooth, but then we saw that every service using client verification was broken after the update.

### Debugging time
To verify the bug I deployed the same code with the two different NodeJS versions (v14.19.3 & v14.20.0). On v14.19.3 I got a HTTP 200 response, on v14.20.0 I got a HTTP 400 response indicating a bad-request. But our application never threw a 400 error - nor did it log anything. - *Time to dig deeper...*

I created a minimal NodeJS http-server and deployed it with the two different NodeJS versions (*and even new ones*):
```JavaScript
const port = 3000;
var http = require('http');

//Dead simple http server:
http.createServer((req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.write(JSON.stringify(req.headers));
  console.log(`REQ FROM: path: ${req.url}; remote: ${req.ip}`);
  console.log(req.headers);
  res.end();
}).listen(port, '0.0.0.0');
```

I got the same behavior 😒. Not a solution but now I knew it wasn't a bug in our application. Is it a bug in NodeJS? In a dot-release? For security fixes?

Let's start by looking at the release notes of [NodeJS 14.20.0](https://github.com/nodejs/node/blob/main/doc/changelogs/CHANGELOG_V14.md#2022-07-07-version-14200-fermium-lts-danielleadams-prepared-by-juanarbol)

```markdown
### Notable Changes
[8e8aef836c] - (SEMVER-MAJOR) src,deps,build,test: add OpenSSL config appname (Daniel Bevenius) #43124
[98965b137d] - deps: upgrade openssl sources to 1.1.1q (RafaelGSS) #43686
### Commits
[b93e048bf6] - deps: update archs files for OpenSSL-1.1.1q (RafaelGSS) #43686
[98965b137d] - deps: upgrade openssl sources to 1.1.1q (RafaelGSS) #43686
[837a1d803e] - deps: update archs files for OpenSSL-1.1.1p (RafaelGSS) #43527
[c5d9c9a49e] - deps: upgrade openssl sources to 1.1.1p (RafaelGSS) #43527
[da0fda0fe8] - http: stricter Transfer-Encoding and header separator parsing (Paolo Insogna) #315
[48c5aa5cab] - src: fix IPv4 validation in inspector_socket (Tobias Nießen) nodejs-private/node-private#320
[8e8aef836c] - (SEMVER-MAJOR) src,deps,build,test: add OpenSSL config appname (Daniel Bevenius) #43124
```

Hmmm - The certificates are generated with *openssl*, but the actual verification takes place before it reaches NodeJS. The only other notable thing is the stricter http parser. Let's take a deeper look.

### Encoding is everything
I want to see the actual HTTP request that gets proxieed to NodeJS. So I replaced the NodeJS application with [Netcat – The Swiss Army Knife of Networking](https://en.wikipedia.org/wiki/Netcat).
With the help of [@bnoordhuis](https://github.com/bnoordhuis) I found that we were getting the following:
```
# HexDump
00000000: 4745 5420 2f20 4854 5450 2f31 2e31 0d0a 436f 6e6e 6563 7469 6f6e 3a20 7570  GET / HTTP/1.1..Connection: up
0000001e: 6772 6164 650d 0a48 6f73 743a 2064 6d2d 7465 7374 696e 672d 7374 6167 696e  grade..Host: dm-testing-stagin
0000003c: 672d 7369 7465 2e63 632d 6973 6f62 7573 2e63 6f6d 0d0a 4d59 5f43 4552 543a  g-site.exampleio.com..MY_CERT:
0000005a: 202d 2d2d 2d2d 4245 4749 4e20 4345 5254 4946 4943 4154 452d 2d2d 2d2d 0a09   -----BEGIN CERTIFICATE-----..
00000078: 4d49 4947 4154 4343 412b 6d67 4177 4942 4167 4942 4154 414e 4267 6b71 686b  MIIGATCCA+mgAwIBAgIBATANBgkqhk
00000096: 6947 3977 3042 4151 7346 4144 4342 6d54 4561 4d42 6747 4131 5545 4177 7752  iG9w0BAQsFADCBmTEaMBgGA1UEAwwR
000000b4: 5132 3974 0a09 6347 4675 6553 3168 6458 526f 6233 4a70 6448 6b78 437a 414a  Q29t..cGFueS1hdXRob3JpdHkxCzAJ
000000d2: 4267 4e56 4241 5954 416b 5246 4d52 5177 4567 5944 5651 5149 4441 744d 6233  BgNVBAYTAkRFMRQwEgYDVQQIDAtMb3
...
```

Do you see these `0a09` sequences? That is the encoding for `\n\t` which is **NOT** a valid sequence for new-lines in HTTP-Headers. But NodeJS accepted these sequences anyway - at least till version v14.20.0.

The correct sequence, based on the protocol, should be `0a0d09` which is `\r\n\t`.

### The Solution:
The solution is easy - just change the way the certificates are encoded! - *Wait! We can't do that!*  
Due to the nature of our service we don't have direct control over the clients connecting to our server. It would be a major inconvenience to change this on all clients. Another option is to start NodeJS with the `--insecure-http-parser` flag - which isn't an option either.   
What about our reverse proxy? Turns out [NGINX](https://www.nginx.com/) has a dedicated variable for client certificates in its [ssl-module](https://nginx.org/en/docs/http/ngx_http_ssl_module.html) since version 1.13.5. Instead of `ssl_client_cert` we could use `ssl_client_escaped_cert` which contains the url-encoded (and therefore valid encoded) certificate.  
A quick test with the new proxy configuration showed that the new NodeJS version was now working. 


### Some Background Information
Planned was the update from NodeJS v14.19.3 to v14.20.0. The above-mentioned CVE's are about the *llhttp* http-parser of NodeJS. It is part of the core of NodeJS and handles http requests *before* any custom JavaScript executed. The security release made the http parser stricter to only accept requests that follow exactly the HTTP protocol standard. The new behavior prevents attackers to use request smuggling.

### What we learned & what we did
Unfortunately deploying these security fixes wasn't as straight forward as we originally thought. We did not expect some of our application to just completely stop working. We needed some time to debug but also didn't want to expose the other *working* services to unnecessary risk. So we updated every application that didn't use client verification as soon as all our tests passed end kept back the update form those that did.  
Two and 1/2 days later we found a solution for the problem and also updated the application that used client verification. We learned about the importance of working within the protocol specification even though some software allows more than it has to. And even though JavaScript is a high level language, it is important to have understanding for the low level actions of the networking-stack. We also got remained that just because it is a dot-release it still can break a lot and case some quality time with your favorite rubber duck 🦆

**See you!**
