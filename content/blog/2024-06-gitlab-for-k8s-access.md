---
title: Using GitLab to manage Kubernetes access
description: You have private Kubernetes cluster or a restricted network. There are modern solution to easily share and manage access with modern secure authentication. Let's dig some tunnels!
date: '2024-06-12'
pic: '/img/blog/kubernetes-glab-auth-logo.jpeg'
tags: ['Kubernetes', 'GitLab', 'Security']
---
# Using GitLab to manage Kubernetes access

Recently I have been tasked to share access to a Kubernetes test cluster with other teams. Easy: Add them to a group in your OIDC provider and set appropriate RBAC rules. Task done - no need to write this.
## BUT: 
Unfortunately I can't have an OIDC provider for non-production clusters... because. *Sighs...*  

<details>
  <summary>TL;DR</summary>
Use Kubernetes built-in OIDC authentication; if this is not possible for whatever reason, the GitLab Kubernetes Agent might be worth a look.

</details>

![Secure Lock Logo Thumbnail](/img/blog/kubernetes-glab-auth-logo.jpeg)

Okay what other options are there for Kubernetes authentication:
 * Webhook Token Authentication
 * Authenticating Proxy
 * Static token file
 * X509 client certificates

Both webhook authentication and an authentication proxy add considerable overhead and ultimately also need to be plunged into a user registry that I can not use or have control of.

**So what about static token files?**  
In practice, I've never seen them outside of test setups. It requires placing a file with the username, secret and groups on every controlplane node. The effort required to manage and sync such a file, containing static **credentials in plain text**, is just nuts. Even more absurd, the api-server has to be restarted every time this file is changed! And since these tokens have no built-in expiration date, you have to delete an entry and restart the api-server if a credential needs to be invalidated. So this is a hard pass!

**So X509 client certificates it is?**  
The X509 client certificates approach does not require the api-server to be restarted and provides a built-in expiration mechanism. Client certificates are a common approach to establishing a secure communication between two entities, it is often also referred to as mutual TLS (mTLS), where both the client and the server have to identify themselves via a certificate. One-directional TLS (where just the server is ensuring its authenticity) is part of almost every website we visit.  
TLS is considered very secure since, it uses asymmetric encryption with private keys, with a complexity between 1024 and 4098 bits, depending on the algorithm. Kubernetes uses mTLS for almost all of its components to establish trusted and secure communication between every part of the cluster. Kubernetes clusters created with kubeadm also create a `admin.conf` which also uses X509 client certificates to authenticate against the Kubernetes api-server.  
These X509 client certificates are the default way to authenticate against a Kubernetes cluster. For easier usage, Kubernetes base64 encodes the certificate and the private key and puts them inside the well-known YAML kubeconfig. The file is most likely located at `~/.kube/config`.

I have gone the X509 client certificates way and if you are interested, below is a rough draft on how you can automate user config creation. But there is a catch too *Sighs...x2*  

<details>
<summary>Creating X509 client certificates</summary>

Every user should have their own personal kubeconfig to ensure proper access controls and auditing capabilities. Unfortunately there is no built-in support from Kubernetes for creating these kube-client-configs. Nevertheless the process can easily be automated.  

The user has to create a new key-pair with openssl which he will use for accessing the cluster later. This can be done with the following command:
```bash
# Bits for the key
KEY_SIZE=4096
# Username
USERNAME=MY_USER
# Groups
GROUP_1=TEAM_A
GROUP_2=TEAM_B

# Creating key and certificate signing request
openssl req -new -newkey rsa:$KEY_SIZE -nodes -keyout k8s-client-1.key -batch -out k8s-client-1.csr -subj "/CN=${USERNAME}/O=${GROUP_1}/O=${GROUP_1}/emailAddress=${USERNAME}@example.com"
```

The resulting certificate signing request (CSR) now has to be signed by the clusters Common Authority (CA).
The signing request can either be done wither the Kubernetes certificate api by creating a `CertificateSigningRequest` or manually by copying the clients CSR to the api-server and signing it with the clusters CA via openssl. The first option is clearly preferable as it does not require access to the node on which the api-server runs on and there is a traceable audit log.  
The resulting certificate and the key are then base64 encoded and inserted into the format of the kubeconfig. The resulting file will have this layout (without the certificate data redacted):
```yaml
apiVersion: v1
kind: Config
current-context: docker-desktop
clusters:
    - cluster:
          certificate-authority-data: LS0...S0K
          server: https://Kubernetes.docker.internal:6443
      name: docker-desktop
contexts:
    - context:
          cluster: docker-desktop
          user: docker-desktop
      name: docker-desktop
users:
    - name: docker-desktop
      user:
          client-certificate-data: LS0...g==
          client-key-data: LS0...o=
```

*NOTE:* If you want a fully automated process for this just send me a massage!
</details>

![Meme - one support for whole company](/img/blog/one-support-meme.png)

### The Problems with static credentials
While mTLS is technical very secure, it still suffers from problems organizational standpoint. From a modern standpoint, certificates are still long-lived credentials. Thanks to the exemplary work done by the [lets encrypt](https://letsencrypt.org/) project, most certificates are issued with shorter lifetimes compared to the previously common validity of 1+ years. Still, a default of three months is a heck longer than the one-hour default lifetime of an OIDC ID-Token.  
It is also possible to revoke certificates, but just like the creation process, it is not that easy to implement this process. Even when these security aspects are not considered, client certificates become hard to manage in larger or dynamic teams. You must have a way to revoke access from a retired team member. When a user needs to be added, the whole certification creation process has to be done again. Authorization should be done on group level basis, but you can't add a group to a certificate after it was issued. This is not flexible and manageable in any larger organization. For this reason, dynamic authentication processes - like OIDC - are often preferred.

*I have a great article about OAuth2 and OIDC coming up soon on my companies website - stay tuned*

## Alternatives
So what are my alternatives?  
The said cluster in deployed in a very restrictive network environment. Ingress is only allowed from specific clients within a corporate network and only specific ports and traffic. Egress is only possible via a proxy. But we needed to deploy from our GitLab (which is on a different network) instance to our cluster.  
Other people solved this by creating GitLab runners within the Kubernetes cluster and saving the kube-client-credentials-conf as a CI secret. **DONT DO THIS!**  

You are pulling in random container images from the internet to your cluster and run arbitrary scripts from CI in your critical application environment. You are risking your cluster health, the confidently of secrets and are giving up a considerable amount of compute. And you also have to maintain the runners. This also violates the ISO 27001 norm since now access is not personalized anymore and auditing is really hard.

### GitLab Agent
Quite some time ago I stumbled upon the GitLab Agent. It's a small application that creates a reverse tunnel between your control-plane and GitLab instance via websockets. This allows you to use any runner in any network location to securely communicate over the GitLab Instance websocket tunnel, via the GitLab agent to your Kubernetes cluster.
GitLab automatically creates short-lived tokens (`CI_JOB_TOKEN`) and only allows authorized users to use the tunnel in CI.

You can install the agent easily with:
```bash
helm repo add gitlab https://charts.gitlab.io
helm repo update
helm upgrade --install test gitlab/gitlab-agent \
    --namespace gitlab-agent \
    --create-namespace \
    --set image.tag=v17.0.0 \
    --set config.token=glagent-xxx \
    --set config.kasAddress=wss://gitlab.example.com//-/Kubernetes-agent/
```

Now you can create a file in you git repo with the path `.gitlab/agents/<agent-name>/config.yaml` and even share the cluster access with other Git projects:
```yaml
ci_access:
  projects:
    - id: my-team/serviceX
    - id: external-team1/projectA
    - id: external-team2/projectB
  groups:
    - id: qa/loadtests
```

No secrets needed, secure and controlled access to the cluster.

*WAIT...That wasn't the problem I wanted to solve. I need to share access with people - not with CI!*

**Good News:** This also works for people.

You can just add the following to your `.gitlab/agents/<agent-name>/config.yaml`:
```yaml
user_access:
  access_as:
    user: {}
  projects:
    - id: global/groups/admins
  groups:
    - id: my-team
    - id: qa/loadtests
```

Now GitLab allows all users that are in these projects or groups to access the cluster endpoint via the agents tunnel.  
The important part in that config is the `access_as.user` property. The Agent will use [impersonation](https://Kubernetes.io/docs/reference/access-authn-authz/authentication/#user-impersonation) to act like the GitLab user that uses the tunnel. That means you can easily set fine-grained permissions via RBAC to only allow the `qa` group read access while the `admins` have cluster-admin roles. If you are a masochist, you can also apply the RBAC rules per user.

### The Solution
Now, all users can configure their kubeconfigs to use the cluster endpoint `https://gitlab.exmaple.com/-/Kubernetes-agent` and use their GitLab credentials to authenticate.  
Basic permissions are handled by GitLab and the fine-grained Kubernetes permissions are controlled via RBAC.

If a team member retires, just remove them from the GitLab group and the access is gone. A new team member needs onboarding, add them to GitLab and he already has access to the cluster. *Easy management and even ISO 27001 compliant* 🙌

<details>
<summary>Complete Kubeconfig</summary>

```yaml
apiVersion: v1
kind: Config
current-context: gitlab-cluster-via-agent-42
clusters:
    - cluster:
        server: https://gitlab.exmaple.com/-/Kubernetes-agent
      name: gitlab
contexts:
    - context:
        cluster: gitlab
        user: gitlab-agent-42
      name: gitlab-cluster-via-agent-42
users:
    # Users can use a pat to access the cluster
    - name: gitlab-agent-42
      user:
        token: "pat:42:XXX"
    # Or use the glab cli for just in time credentials with a 24h expiry
    - name: gitlab-agent-42-glab
      user:
        exec:
            apiVersion: client.authentication.k8s.io/v1
            args:
                - cluster
                - agent
                - get-token
                - --agent
                - "42"
            command: glab
            env:
                - name: GITLAB_HOST
                  value: https://gitlab.example.com
                - name: GITLAB_CLIENT_ID
                  value: XXX
            installHint: "To access the cluster install glab. Instructions at https://gitlab.com/gitlab-org/cli#installation.\n"
            interactiveMode: Never
            provideClusterInfo: false

```
</details>


## Side Notes
This is not the only solution to access private clusters. But this did the job and security is fine with it. Jump Hosts, VPNs and SSH tunnels are also commonly used but they are often a nightmare to manage or to set up.
A notable alternative is tailscale which also creates a tunnel to you tailnet and allows for user authentication. Unfortunately, tailscale is not used at my current gig.

While these are solutions, I still would recommend to just hook your OIDC provider such as ActiveDirectory, LDAB or Keycloak into the Kubernetes api-server. It is also a much more standardized solution and should be the primary source for all user contexts.  
To my surprise not many managed Kubernetes offerings support setting the OIDC args for the api-server. So this might after all be a good solution if your Kubernetes provider is lacking.

<!---




---
Having access to a Kubernetes cluster gives developers a high degree of automonie. They can deploy, update and debug services in a production like enviorment. But it also. This freedom, however, comes with great responsibility. Developers now have not just one machine at their disposal, but a whole range of machines at once. It often also gives them access to certificate managment and often even DNS zones.  

In traditional IT, these were areas that were strictly separated between developers and operators. With the rise of the DevOps approach, these boundaries are becoming increasingly blurred. However, especially in large companies, it is still crutial to separate certain resources between teams according to their responsibilities.


## Types of authentication
When consulting the [Kubernetes doukentation](https://Kubernetes.io/docs/reference/access-authn-authz/authentication) regarding authentication is are a bunch of different strategies to authenticate. These can be catagrized into these types:
 
  * Static Authentication
	  * X509 client certificates
	  * Static token file
	  * Bootstrap tokens
	  * Service account tokens
  * Dynamic Authentfication
	  * OpenID Connect Tokens
	  * Webhook Token Authentication
	  * Authenticating Proxy

## Static Tokens
When looking at the static authentication methods, these can be further subdivided. Both Bootstrap tokens and Service account tokens are primarly used for in-cluster authentication. Bootstrap tokens are tokens that are justed jused to add a new node to a cluster. In general they have a short expiration time and a very limited scope of allowed actions. The kubelet uses these to request a client-configuration set which will be used for all further requests.  
The Service account tokens are compleatly managed by Kubernetes and are intendet to allow pods within the cluster to communicate with the api-server. When a new pod is created, Kubernetes mounts the Service account tokens as a file into the pods filesystem at a wellknown location if not configured otherwise. 


## Dynamic Authtification
The lack of easy creation and managment of these static authentication processes is the reson manny managed Kubernetes offerings recommend using dynamic approches that integrate within the existing organization.  
This can be done with Webhook Token Authentication or a Authenticating Proxy but as staited above these can be implemented in any imagable way and will not be further discussed here. Insted this article will focuse on OpenID Connect and will also give an alternative if OIDC is not an option. 

-->
