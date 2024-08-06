---
title: The recurring problem of the Kubernetes metrics server and insecure Kubelet certificate
description: The Metrics Server frequently encounters verification issues with Kubelet's self-signed certificates. I wrote a small summary and make a proposal for fixing it.
date: '2024-05-18'
pic: '/img/blog/kubelet-insecure.png'
tags: ['Kubernetes', 'TLS', 'Security']
---
## The recurring problem of the Metrics Server and Insecure Kubelet certificate

### What is this about:  
Currently the kubelet, the client agent coordinating container lifecycle on each node, also runs a server, using a self signed certificate by default. Therefore any client connecting the the kubelet server, most prominent the metrics server, will not be able to verify the servers identity.

![Avengers style fight scene with GitHub OctoCat and GitLab mascot](/img/blog/kubelet-insecure.png)


### Current state:  
Currently if the kubelet starts and no `--tls-cert-file` and `--tls-private-key-file` are specified it generated a self-signed pair and uses it for its server component according the [kubelet docs](https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/)  
The is a feature feature flag called `RotateKubeletServerCertificate` which would allow the use of `serverTLSBootstrap`. This uses the native `CertificateSigningRequest` (csr) resource wich is part of the `certificates.k8s.io/` api. When `serverTLSBootstrap` is enabled the kubelet creates a csr via the kubernetes certificates api for its server component. Users can either approve the csr manually with `kubectl certificate approve <my-csr>` or create a rolebinding wich allows for auto-approve. The resulting cert is singed by the clusters ca if the kube-controller has access to the ca cert and key (most likely it has).  
The process is described in the [tls-bootstrapping](https://kubernetes.io/docs/reference/access-authn-authz/kubelet-tls-bootstrapping/#certificate-rotation) documentation, this provides the prerequisites for a trust chain verification.

### The problem:  
With self-singed certificates there is no way to reliable verify the kubelet's server identity. Even the metrics-servers docs says that passing `--kubelet-insecure-tls` is not a solution for production.  
The recent addition `serverTLSBootstrap` is an approvement but the control over the created csr is very limited to non existed. Most Kubernetes setups are not trivial. Nodes have multiple IPs and may be available over one ore move dns names, let alone IPv6 addresses. From my experience and according to other posts the created kubelet csr does not contain any SANs which could identify the server. The CN ist set to `system:node:<name>` wich is NOT a valid DNS name.  
This lack over the certificate details also results in the lack of the possibility to verify the identity of the kubelet server. Binging us back the the need for `--kubelet-insecure-tls` for all clients talking to the kubelet. Even managed kubernetes offerings have this problem.

### The Proposal:  
Kubernetes admins and vendors should have an easy possibility to crate trusted kubelet server certificates.  
This can be achieved either via the certificate generation phase of kubeadm or via passing extra args to the kubelet tls setup to include additional SANs.

```yaml
# Existing behavior with etcd and kube-api-server
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
apiServer:
  certSANs:
    - "10.100.1.1"
    - "ec2-10-100-0-1.compute-1.amazonaws.com"
etcd:
  local:
    imageRepository: "registry.k8s.io"
    serverCertSANs:
      -  "ec2-10-100-0-1.compute-1.amazonaws.com"
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
nodeRegistration:
  name: "ec2-10-100-0-1"
  kubeletExtraArgs:
    node-ip: "10.100.0.1"
    # Proposal: ether as an arg
    serverCertSANs: "10.100.0.1,ec2-10-100-0-1.compute-1.amazonaws.com"
  # Proposal: or as an own kubeadm nodeRegistration property 
  serverCertSANs: 
    - "10.100.0.1"
    - "ec2-10-100-0-1.compute-1.amazonaws.com"
```

Personal I'm in favor of adding an extra arg to the kubelet binary to include a list of additional SANs. This would also allow profit users not using kubeadm to have a properly configured kubelet server certificate.

### The Workaround:  
For personal testing setups I use ansible to prepare my nodes and bootstrab a cluster. One the certificate generation phase is complete I can generate my onw private key and certificate request and sing it with the clusters ca. 
Though I don't recommend this for production, this is why we need a more managed and automated approach. 

### References
 * [Kubernetes Docs TLS Bootstrap](https://kubernetes.io/docs/reference/access-authn-authz/kubelet-tls-bootstrapping/#certificate-rotation)
 * [Kubernetes Docs kubeadm troubleshoot tls](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/troubleshooting-kubeadm/#cannot-use-the-metrics-server-securely-in-a-kubeadm-cluster)
 * [GitHub metrics-server error - missing SANs](https://github.com/kubernetes-sigs/metrics-server/issues/196)
 * [GitHub kubernetes node - missing SANs](https://github.com/kubernetes/kubernetes/issues/59372)
 * [GitHub kubernetes singed serving certificates ](https://github.com/kubernetes/kubeadm/issues/1223)
 * [Reddit - kubeadm not including SANs](https://www.reddit.com/r/kubernetes/comments/1028mw3/kubeadm_join_add_ip_sans_to_kubelet/)
