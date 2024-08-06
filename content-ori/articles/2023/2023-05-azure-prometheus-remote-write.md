---
title: How to send OnPrem Prometheus metrics to MS Azure
description: Companies have to bridge the gap when moving to the cloud. One of the major pain points is observability. This quick post shows how to send your OnPrem metrics to Azure in order to provide a central location for your "single pane of glass" observability.
date: '2023-05-25'
pic: '/img/blog/azure-prometheus-monitor.png'
tags: ['NodeJS', 'NoteBook', 'Joplin', 'OneNote', 'Markdown', 'Dev', 'TS/JS']
---

# Sending metrics to Azure - with Prometheus
---
With this post, I want to provide a quick demonstration on how to send Prometheus metrics to Azure managed Prometheus. Let's get stared.

<!-- ![Azure meets Prometheus](/img/blog/azure-prometheus-monitor.png) -->
## What is Prometheus
Prometheus is an open-source monitoring system that scrapes (pulls) system and application metrics from supported targets. It is an graduated project of the Cloud Native Computing Foundation (CNCF) and the de facto standard in the Kubernetes world. It also supports service discovery and alerting. The major drawback of Prometheus is, that it stores it's metrics in block storage as local files and has no native support for clustering multiple instances. Horizontal scaling is therefore difficult to archive.

## Why send metrics to Azure
Cloud services as Azure and Grafana Cloud solve the clustering and storage issues of a single Prometheus instance by providing managed services. (Often implemented through [Mimir](https://grafana.com/oss/mimir/).) Companies can send metrics from multiple Prometheus instances and different locations, all to a single location, which minimizes duplicated setups (cost), the risk of a singe point of failure and provides scaling, while also providing a single location (called a single pane of glass) for service performance data. When using Azure, Prometheus also integrates nicely with AKS and other Azure services, even without the need of credentials due to service principles.  
Prometheus supports sending data to a different location using the `remote_write` feature, which I will use here to sent data from any system and app to Azure.

## Setting up Azure Prometheus
For simplicity, I will demonstrate the set up process using the Azure Portal. But the process can also be automated via the CLI or terraform.  
You have to do the following steps:
 * Log into Azure
 * Search for Prometheus
 * Start Creating a Prometheus instance
   * Set a name and location
   * Allow public networking
   * Create and wait

This will create a new managed monitor resource-group with your Prometheus instance. 
![Azure meets Prometheus](/img/blog/azure-prom-1-create.png)
Write down the *Metrics ingestion endpoint*

Next step is to create an App/User that can push to that endpoint. For this we:
 * Open the Azure Active Directory 
 * Go to App Registrations
 * Click New Registration
   * Provide a name
   * Choose single tenant mode
 * Go to Certificates & Secrets

For simplicity we use a secret in this demo, but a certificate is safer and recommended. It is best practice to store the certificate in a vault (like Azure Keyvault or Hashicorp Vault) and only request the credentials via the vault's API. A guide how to do this can be found [here](https://learn.microsoft.com/en-us/azure/key-vault/certificates/quick-create-portal#add-a-certificate-to-key-vault).

Create a secret and copy it (you will not be able to see it again). Go back to the overview of the created app registration.
![Azure meets Prometheus](/img/blog/azure-prom-2-user.png)
Copy the ClientId and then press on *Endpoints* to copy the *OAuth 2.0 token endpoint (v2)* URL.

Next, we need to authorize our user to push metrics to the *Metrics ingestion endpoint*. Go back to the created resource-groups for the Prometheus instance and go to *Access Control (IMA)*. On the role-assignment tab, add a new role-assignment with the role of *Monitoring Metrics Publisher* and assign it to the created user from the previous step.
![Azure meets Prometheus](/img/blog/azure-prom-3-access.png)

This is it for the azure site!

## Sending Metrics
Now we can set up our local tools to send metrics.

The flow we created uses the OpenIdConnect (OIDC) standard which is part of the Oauth2 spec. When you want lo learn more abut the described authentication, you can check out this in depth article **TBA**.

To send metrics form on Prometheus instance we need to set up the Prometheus config like this:
```yml
global:
  scrape_interval: 1m

scrape_configs:
  - job_name: "INTERNAL"
    honor_labels: true
    static_configs:
    - targets: ["localhost:9090"]

remote_write:
  - name: azure-write
    url: <Metrics ingestion endpoint>
    headers:
      X-Scope-OrgID: anonymous
    oauth2:
      client_id: <ClientId>
      client_secret: <ClientSecret>
      token_url: <OAuth 2.0 token endpoint (v2)>
      scopes: [ https://monitor.azure.com/.default ]
```
Thats it.

Start your Prometheus instance and see the logs that are coming in. You can visualize them in Azure Monitor or via the Azure Managed Grafana.

**See you!**
