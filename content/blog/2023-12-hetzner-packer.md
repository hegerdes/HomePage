+++
title = "Building preconfigured OS images with HashiCorp Packer"
description = "This article explains how to create custom OS images for Hetzner Cloud VMs using HashiCorp Packer."
date = '2023-12-12'

[taxonomies]
categories=["it"]
tags =["Hetzner Cloud", "IaC", "Packer", "CloudInit", "Linux"]

[extra]
pic = "/img/blog/software-packaging.jpeg"
+++
# Building preconfigured OS images with Packer

## Introduction

Hetzner Cloud provides a number of different operating system images to select from when creating a new virtual machine. These images provide the basic ground to get started with your service, but they are rarely configured according to your specific needs. Maybe you want to install a database or a web server, add a maintenance user, or just tweak system settings to improve performance and security. While there are tools to do this automatically for every new VM, this takes time and may not always be reproducible. Wouldn't it be easier to have your own known good personal pre-configured OS image that you can use for every new VM?

This can be archived with HashiCorp Packer.

This article demonstrates how to use Packer to create custom images for your Hetzner VMs using Infrastructure as Code (IaC). It even allows users to create VMs with operating systems that are not officially supported by Hetzner.

*Note:* This article was also published on [Hetzner's Community Blog](https://community.hetzner.com/tutorials/custom-os-images-with-packer)
![software-packaging.jpeg](/img/blog/software-packaging.jpeg)


**Prerequisites**

To follow this tutorial, you need:

* Hetzner Cloud [API token](https://docs.hetzner.com/cloud/api/getting-started/generating-api-token) in the [Cloud Console](https://console.hetzner.cloud/)
* Access to the Internet

## Installing Packer

Visit [Hashicorp Packer](https://developer.hashicorp.com/packer/install) and install Packer according to your OS.  
On Debian based Linux, run:

```bash,linenos
# Get the latest version
curl -sL https://api.github.com/repos/hashicorp/packer/releases/latest | jq -r .tag_name
# Set the version and download
PACKER_VERSION=1.11.2
curl -sL https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip -o /tmp/packer.zip
# Unzip - may needs sudo
unzip -q /tmp/packer.zip -d /usr/local/bin -x "LICENSE.txt"
```

You can run `packer --version` to view the version and check if the installation was successful.

## Creating a custom image

Create a project folder with `mkdir my-hetzner-img` and enter the directory.  
Similar to Terraform, Packer uses providers to communicate with the needed build system. The usage of different providers allows Packer to offer a vast verity of different target systems. It allows users to create software or OS packages for all major cloud providers, on-prem systems and even Docker images.  
To use a provider, create a file called `provider.pkr.hcl` and add the provider config:

```hcl,linenos
# packer.pkr.hcl
packer {
  required_plugins {
    hcloud = {
      source  = "github.com/hetznercloud/hcloud"
      version = ">= 1.2.0"
    }
  }
}
```

Packer uses the HashiCorp configuration language (HCL) for declaring the desired state, just like Terraform.

To create a personalized custom image, Packer needs a base form where it starts from. This is called the "source":

```hcl,linenos
# custom-img-v1.pkr.hcl
source "hcloud" "base-amd64" {
  image         = "debian-12"
  location      = "nbg1"
  server_type   = "cx11"
  ssh_keys      = []
  user_data     = ""
  ssh_username  = "root"
  snapshot_name = "custom-img"
  snapshot_labels = {
    base    = "debian-12",
    version = "v1.0.0",
    name    = "custom-img"
  }
}
```

This tells Packer where to start. In the case of Hetzner, Packer needs to know the base image, the server type to use for building, and the location of that server. It also specifies the name of the Snapshot that will be created and the tags that should be applied to that server.

The next step is to provide your customization. Meaning the actual build step.

```hcl,linenos
# custom-img-v1.pkr.hcl
build {
  sources = ["source.hcloud.base-amd64"]
  provisioner "shell" {
    inline = [
      "apt-get update",
      "apt-get install -y wget fail2ban cowsay",
      "/usr/games/cowsay 'Hi Hetzner Cloud' > /etc/motd",
    ]
    env = {
      BUILDER = "packer"
    }
  }
}
```

It uses the source specified before and specifies a `shell` provisioner. Every line in `inline` will be executed on that server. In this case, it installs `fail2ban` to harden the server by slowing down the 1000s of SSH login attacks that happen regularly and adding a little message to the `motd` file.

> **Note:** When you run `packer build .`, Packer will automatically create a new server and a new Snapshot in your Hetzner Cloud project. Both will be charged. The server is **automatically** deleted immediately after either the Snapshot was created or the creation failed.

To create that image run the following commands:

```bash,linenos
# Set your Hetzner API Token
export HCLOUD_TOKEN="XXX"
# Initialize the project - only needed once
packer init .
# Build
packer build .
```

Now Packer builds that server and streams all the logs to your current terminal. Verify that the new image is available in the Hetzer [Cloud Console](https://console.hetzner.cloud/):

![image-overview-1.png.png](/img/blog/hetzner-image-overview-1.png)

## Taking it to the next level

Putting all commands in HCL can quickly get crowded. It is also not reasonable to copy-paste the code for every variant of an image you might want to build. To make things more generic, Packer can use variables:

```hcl,linenos
# custom-img-v2.pkr.hcl
variable "base_image" {
  type    = string
  default = "debian-12"
}
variable "output_name" {
  type    = string
  default = "snapshot"
}
variable "version" {
  type    = string
  default = "v1.0.0"
}
variable "user_data_path" {
  type    = string
  default = "cloud-init-default.yml"
}

source "hcloud" "base-amd64" {
  image         = var.base_image
  location      = "nbg1"
  server_type   = "cx11"
  ssh_keys      = []
  user_data     = file(var.user_data_path)
  ssh_username  = "root"
  snapshot_name = "${var.output_name}-${var.version}"
  snapshot_labels = {
    base    = var.base_image,
    version = var.version,
    name    = "${var.output_name}-${var.version}"
  }
}

build {
  sources = ["source.hcloud.base-amd64"]
  provisioner "shell" {
    scripts = [
      "os-setup.sh",
    ]
    env = {
      BUILDER = "packer"
    }
  }
}
```

Now, we can specify and override the base image at runtime by using `packer build -var bas_image=ubuntu-22.04 -var version=v1.1.0 .`. This version also uses the `scripts` parameter rather than in-lining all the commands. This allows for much more complex setups. It also uses [cloud-init](https://cloudinit.readthedocs.io/en/latest/) to configure some settings declaratively.

Hetzner also supports [Arm64-based servers](https://www.hetzner.com/press-release/arm64-cloud) which offer a great price-to-performance ratio and impressive efficiency. Due to the different nature of Arm, software needs to be compiled for this architecture and all configurations also need to be applied for this architecture. Fortunately, Packer allows to reuse any build scripts for Arm.

Just add another source to your code and update the build step to include that source:

```hcl,linenos
# custom-img-v2.pkr.hcl
source "hcloud" "base-arm64" {
  image         = var.base_image
  location      = "nbg1"
  server_type   = "cax11"
  ssh_keys      = []
  user_data     = file(var.user_data_path)
  ssh_username  = "root"
  snapshot_name = "${var.output_name}-${var.version}"
  snapshot_labels = {
    base    = var.base_image,
    version = var.version,
    name    = "${var.output_name}-${var.version}"
  }
}
...
build {
-  sources = ["source.hcloud.base-amd64"]
+  sources = ["source.hcloud.base-amd64", "source.hcloud.base-arm64"]
  provisioner "shell" {
...
```

This version now automatically builds images for Arm64-based servers.

## Tips and advanced usage:

**About disk size:**<br>
You may have noticed that the code above uses the smallest instances available on Hetzner. This is not only to reduce cost but also allows for the created Snapshot to be deployed for every VM. Due to the way disks are managed at Hetzner, a new VM must have a disk that is at least the same size as the one from which the Snapshot was created. Using an eight-core server might be a little faster than using a smaller one, but it would limit the servers you can deploy form this image to VMs with at least 240GB disks.

**About Tags:**<br>
Tags are metadata that you can add to a Snapshot. These are useful to provide information about the origin of an image and what it is used for. Also, tags are the only way to select an existing Snapshot in Terraform to deploy a new VM. They should definitely be used.

**About cloud-init:**<br>
You can use `cloud-init` to do some early setup while building images with Packer, but you might also want to use `cloud-init` when deploying your custom image. By default, `cloud-init` only runs once, so it needs to be reset.  
Consider adding the following lines to your bash script to wait and reset `cloud-init`.

```bash,linenos
# os-setup.sh
#!/bin/bash
set -e -o pipefail

echo "Waiting for cloud-init to finish..."
cloud-init status --wait

echo "Installing packages..."
apt-get update
apt-get install --yes --no-install-recommends wget fail2ban

# My setup...

echo "Cleanup..."
cloud-init clean --machine-id --seed --logs
rm -rvf /var/lib/cloud/instances /etc/machine-id /var/lib/dbus/machine-id /var/log/cloud-init*
```

This allows users to run `cloud-init` a second time.

**Different operating systems:**<br>
You can create and boot completely different operating systems and create your own images for them using Packer. By booting into Hetzner's *rescue* mode, you can override the entire disk image of a VM:

```hcl,linenos
build {
  sources = ["source.hcloud.myvm"]
  provisioner "shell" {
    inline = [
      "apt-get install -y wget",
      "wget https://github.com/siderolabs/talos/releases/download/v1.5.5/hcloud-amd64.raw.xz",
      "xz -d -c hcloud-amd64.raw.xz | dd of=/dev/sda && sync",
    ]
  }
}
```

My personal use case for Packer is to create preconfigured Kubernetes images with fine-tuned system parameters and preloaded container images. The horizontal autoscaler can use these images to provision new worker nodes quickly and reliably. But there are plenty of other use cases.

![image-overview-2.png.png](/img/blog/hetzner-image-overview-2.png)

For further configuration, check out the [Packer documentation](https://developer.hashicorp.com/packer/tutorials) and the [Hetzner Packer builder documentation](https://developer.hashicorp.com/packer/integrations/hetznercloud/hcloud/latest/components/builder/hcloud).  
You can find the entire code used in this article can be found on [GitHub](https://gist.github.com/hegerdes/deb361b1383c76e9dabbe030c607ac51).

## Conclusion

This article gave a comprehensive guide on how to install and use HashiCorp Packer. It provided a base project on how to use Packer to create custom OS images for Hetzner Cloud VMs, leveraging Infrastructure as Code practices. It also addressed advanced using variables and cloud-init. This approach allows for the creation of tailored, pre-configured OS images, offering a more efficient and streamlined process for deploying VMs with customized settings and applications.
