---
title: Comparing GitHub Actions with GitLab CI/CD - A deep dive!
description: CI/CD systems are the core component of modern development processes. They ensure quality, reproducibility and save huge about of time for developers. Choosing and knowing your tools ensues how to properly chose and make sure they fulfill their requirements.
date: '2024-01-31'
pic: '/img/blog/github-vs-gitlab-comic.jpeg'
tags: ['GitHub', 'GitLab', 'CI/CD', 'Automation', 'VCS']
---

# Comparing GitHub Actions with GitLab CI/CD 

## Introduction

GitLab just announced the availability of their [GitLab CI/CD Catalog (2023/12),](https://about.gitlab.com/blog/2023/12/21/introducing-the-gitlab-ci-cd-catalog-beta/) which states a perfect opportunity to compare the current state of the two CI/CD systems of everyone's favourite version control providers: GitLab CI & GitHub Actions.

*Disclaimer:* While there are a lot of other CI/CD systems like Circle CI, Azure DevOps, AWS CodeBuild, Travis CI and surprisingly, even Jenkins is still around, these tools are dedicated to solving one problem and are not part of a fully integrated developer platform. I also have not used most of them to a sufficient extent to be able to provide a meaningful review. This post only focuses on GitLab CI and GitHub Actions, especially their SaaS offerings, from a technical and software engineering standpoint. The value of these tools may vary depending on your specific requirements.

![Avengers style fight scene with GitHub OctoCat and GitLab mascot](/img/blog/github-vs-gitlab-comic.png)

## General CI setup & flow
GitHub Actions and GitLab both define their CI/CD procedures using `yaml` files which will be parsed, templated/interpolated, and processed by the CI/CD task scheduler. In general, one or more jobs are created which run in one or more stages. By default, jobs within one stage run in parallel, while stages run in sequence. 
Naturally, both GitHub Actions and GitLab have first-party integration support within their Git hosting platforms. While they can also be used to run tasks for Git repos hosted on a third-party service, it comes with limitations, often making it impractical. In fact, many triggers for the CI/CD jobs are directly related to the Git repositories on which they perform these actions. While GitHub evaluates each file in `.github/workflows` individually by checking if the emitted event matches one of the [many workflow triggers](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows) specified via the `on:` keyword, GitLab only has one CI file called `.gitlab-ci.yml`. Whereas this file can include separate CI configurations, GitLab always merges all definitions into a single monolithic file and evaluates on a job-by-job base if the job should be created and run or not.

GitHub has a lot of triggers for every imaginable event that might accrue within a GitHub repository. Workflows can be run when an issue is created, labelled, or a comment is added. GitLab, on the other hand, only has the predefined `CI_PIPELINE_SOURCE` variable which, in combination with other [predefined variables,](https://docs.gitlab.com/ee/ci/variables/predefined_variables.html) can be used to decide if a CI job is created. It does not support events like issues or comments. However, integration with external event sources is more flexible in GitLab CI with the choice of `API`, `Triggers` and chat, enabled by the direct integration support of various applications such as Slack. GitHub only allows to manually create CI jobs via the `workflow_dispatch` event, which can be triggered via the API or the WebUI. These and other differences also affect the way variables and tokens are used for these CI/CD systems. Basic event triggers such as the `push` of a branch/tag or `merge_requests` are supported by both systems.

## Building the Jobs
Based on the event and its values, the specified CI/CD jobs get created. While the general declaration of a job definition is quite similar, the specification and execution of the actual commands are quite different. Each job has a name, a selector to specify the runner, variables and script or step property. Both systems also support a matrix property to run one job definition multiple times for different environments, runtime versions or operating systems. Users can reference variables, secrets and event values within a job definition. GitHub even allows the usage of a limited set of [expressions](https://docs.github.com/en/actions/learn-github-actions/expressions) to compare, encode or alter the content of variables. It also includes an additional property to determine if a job should be run after evaluating the `on` property of a workflow file. GitLab only has one level of conditionals defined via it's `rules` property.  
Every job can also specify dependencies on other jobs. The actual steps that the CI should run are specified differently depending on the system used:

### GitHub Actions
GitHub Actions allows users to run an arbitrarily amount of action modules. An action is a (specific) reference to a other Git repository that performs a specific task within the CI. When a job is run, the action is checked out and runs its logic. From the users perspective, most actions are declarative, which allows users to utilize them without having to know their implementation details. Examples of actions include [installing Docker](https://github.com/marketplace/actions/setup-docker) or [setting up Minikube](https://github.com/marketplace/actions/setup-minikube). GitHub has a huge [marketplace](https://github.com/marketplace?type=actions) of official and community actions. Users can customize the behavior of actions by passing input arguments to them. This approach allows for great reuse of tasks, a low entry barrier, and lean CI configurations.  
Besides the marketplace actions users can also use a generic `run` action, which accepts any shell code, allowing any generic imperative commands. In addition to Bash and PowerShell, it is also possible to directly use Python, JavaScript and other interpreted languages. In addition to workflow control and job control, each step has an optional parameter to determine if the step should be executed. 

```yaml
# GitHub Action example workflow
name: Example Pipeline

on:
  pull_request:
    branches: ['releases/', 'main']
  push:
    branches: [main]

jobs:
  code-style:
    runs-on: ubuntu-latest
    steps:
    - name: checkout
      uses: actions/checkout@v4

    - name: Info for main branch
      if: github.ref == 'refs/heads/main'
      run: echo "Running tests in main"

    - uses: actions/setup-python@v5
      with:
        python-version: '3.11'

    - uses: hashicorp/setup-terraform@v3
    - uses: terraform-linters/setup-tflint@v4.0.0
    - uses: pre-commit/action@v3.0.0
```

### GitLab CI
GitLab has three different run stages: `before_script`, `script` and `after_script`. Each stage allows a list of shell commands and can execute everything a script could. The `after_script` is always executed, even if previous steps errored. Allowing users to send webhooks, perform error handling and print debug messages. Reusing these scripts is possible via inheriting from an existing job, extending from an existing job, or using the `!reference` tag which allows using commands specified somewhere else. All commands have to be imperative shell instructions, which requires users to carefully construct every task they want to perform themselves.

```yaml
# GitLab CI Pipeline example

tags: [docker]
variables:
  MY_GLOBAL_VAR: Foo
  GIT_DEPTH: 5

# include:
#   - template: Terraform.latest.gitlab-ci.yml
#   - template: Security/SAST.gitlab-ci.yml

Build-Image-Buildah-Template:
  image: registry.access.redhat.com/ubi8/buildah:latest
  stage: build
  variables:
    REGISTRY: ${CI_REGISTRY}
    REGISTRY_USER: ${CI_REGISTRY_USER}
    REGISTRY_PASS: ${CI_REGISTRY_PASSWORD}
    CONTEXT: $CI_PROJECT_DIR
    BUILD_IMAGE_TAG: $CI_REGISTRY_IMAGE:$CI_COMMIT_REF_NAME
    DOCKERFILE: $CONTEXT/Dockerfile
  script:
      - buildah login -u "${CI_REGISTRY_USER}" -p "${CI_REGISTRY_PASSWORD}" "${CI_REGISTRY}"
      - |
        buildah bud --pull \
          --build-arg COMMIT_HASH=$CI_COMMIT_SHORT_SHA \
          --build-arg COMMIT_TAG=$CI_COMMIT_REF_NAME \
          --tag "${BUILD_IMAGE_TAG}" \
          --file ${DOCKERFILE} ${CONTEXT}
      - buildah push --creds "${REGISTRY_USER}:${REGISTRY_PASS}" "${BUILD_IMAGE_TAG}"
  rules:
    - if: $CI_PIPELINE_SOURCE == "schedule"
    - if: $CI_PIPELINE_SOURCE == "push"
    - !reference [.global, default_rules]
```

### Differences
GitHub's prebuild actions allow for an easy-to-use and quickly configured CI. They are great for reusability and the abstraction of low-level tasks. However, users and organizations must keep in mind that actions in the community marketplace is code written by others. It is recommended to check all actions before using them and to pin their reference to a specific commit to prevent supply chain attacks. GitLab's approach requires more effort upfront and a deeper knowledge about every step in the setup to perform. While GitLab also allows reusing jobs, it is not as powerful as the later sections will show. The fine-grained and clear structure of GitHub Actions, that determines whether a workflow, job, or step should be executed is an advantage over the monolithic approach of GitLab.

## Reusing CI Configurations
GitHub Actions allow for great usability at the task level, as the previous section already showed. However, CI jobs are rarely constructed of just on step. Most jobs include checking out the code, installing the language runtime, downloading build dependencies and performing some checks. A Docker build job is almost always the same, just like security scans. They just need some arguments that point to the source and parameters for the output artifact. In an organization, it might be desirable to share these common build steps to keep it *DRY* and reduce code hygiene maintenance. This would also assure that all jobs are compliant with internal standards and policies.  
GitHub Actions offer [reusable workflows,](https://docs.github.com/en/actions/using-workflows/reusing-workflows) which are GitHub Action workflow files that can be called from any other project. These reusables define one or more jobs and offer inputs to customize how the included jobs are run. Being built on Git, these workflow files are versioned and can be pinned to a specific commit.  
For GitLab, the story is a little more complicated. GitLab uses a monolith `.gitlab-ci.yml` file in which all jobs are defined. But the jobs don't have to be declared within that file. They can be included from another project or any other file that is accessible via HTTP from the GitLab instance. In general, there are two types of `includes` in GitLab, both can have multiple nested includes of their own. There is the generic include of any other job definition file that is offered by a shared repository or a third-party entity. The second type is the official [GitLab CI/CD template](https://gitlab.com/gitlab-org/gitlab/-/tree/master/lib/gitlab/ci/templates) type. These templates are common CI/CD jobs that are directly provided by GitLab and come with every GitLab installation. Both types do not provide the possibility of directly passing inputs to the included jobs. All customizations must be done via GitLab's CI/CD variables or by explicitly overriding the job to fit the desired needs. To apply these customizations, it is often necessary to look at the source of a specific job, which might be defined in multiple levels of nested includes.  
On December 21, 2023, GitLab announced the beta availability of the [GitLab CI/CD Catalog (2023/12)](https://about.gitlab.com/blog/2023/12/21/introducing-the-gitlab-ci-cd-catalog-beta/). This feature enables a third type of job inclusion into the `.gitlab-ci.yml`. It provides a community store where every user can create their own definitions for one or more jobs. Anyone can include these components and customize them via a series of inputs. Consumers just need to look at the component page of the catalog item to get a list of all available inputs and further documentation. It's a much cleaner interface between the provider and consumer of a job. Just like it is with GitHub Actions on the individual task level. The difference is that these catalog items still don't let users fully alter any jobs on the individual task level. The components include whole jobs and are therefore more similar to GitHub's reusable workflows than GitHub's Action. A list of already available GitLab CI/CD Components can be found [here](https://gitlab.com/explore/catalog).  
Creating your own component is quite easy. GitLab requires a specific repository layout and a label on the project to specify it as a CI/CD Component. With GitLab releases, a new version of that component is created. To test this new functionality, I created [my own component](https://gitlab.com/hegerdes/gitlab-actions) that builds Docker images with Googles kaniko builder (which does not require Docker in Docker) and automatically applies some common OCI spec labels. Feel free to check it out.  
*NOTE:* Just like third-party GitHub Actions, before using a third-party component, it should be verified and pinned to an exact version. 

While the CI/CD Components are a step towards a more user-friendly and reusable CI code, they still don't offer fine-grained control. GitHub's conditional controls on workflow, job and step level offer a much more flexible setup and expose a cleaner solution than GitLab by including, merging, extending and overriding jobs from many sources. The complete `.gitlab-ci.yml` file with all overrides, references and includes applied can be viewed in GitLab's pipeline editor. However, due to the multiple inclusions, this file can quickly become a few thousand lines long and is not very user-friendly to read.

## Runners
To run the defined CI/CD jobs, both GitHub and GitLab need runners. Both services offer *Hosted Runners* that are owned and maintained by the respective provider (SaaS offering). Each provider offers a free plan for their CI/CD runners, which includes a certain amount of compute minutes. The table below shows a brief, none complete overview of their offerings. 

| Plan        | Included Minutes | Price | Cost per minute/per core for additional minutes |
| ----------- | ---------------- | ----- | ----------------------------------------------- |
| GitHub Free | 2000             | 0$    | 0.004$*                                         |
| GitHub Pro  | 3000             | 4$    | 0.004$*                                         |
| GitLab Free | 400              | 0$    | 0.005$*                                         |
| GitLab Pro  | 10.000           | 29$   | 0.005$*                                         |

*Note:* Cost per minute is for extra minutes that exceed the included minutes. It is calculated based on available price information.

This table is not representative of real-world costs because both providers offer a variety of different runner sizes with different operating systems. Based on the size and operating system (OS), there is a cost multiplier that is factored in for every real compute minute consumed. The numbers in the table are for the default (smallest) runners based on a Linux system. For specific use cases, please refer to [GitHub's pricing docs](https://docs.github.com/en/billing/managing-billing-for-github-actions/about-billing-for-github-actions) or [GitLab's pricing docs](https://docs.gitlab.com/ee/ci/pipelines/cicd_minutes.html#additional-costs-on-gitlab-saas).  
Both providers offer Linux, macOS and Windows runners. At the time of writing, GitLab's offerings for macOS and Windows are still in beta.
GitHub's runners are hosted on the Azure Cloud using the `Standard_DS2_v2` series VMs and GitLab's runners are hosted on Google Compute Platform (GCP) using the `n2d_machines` series. Both runner offerings are hosted in the US only currently, which may have an impact on latency and can interfere with privacy constraints.  
The architecture of both CI/CD systems envisions that the available runners continuously communicate with the GitHub/GitLab instance and process jobs from their task queue. Only the GitHub/GitLab instances has to be accessible by the runners, the runners themselves don't need to be exposed to the internet. This can be important for certain restrictive network topologies. While the CI/CD job scheduling is quite similar, there are some differences between GitHub and GitLab in how the jobs are executed.

### GitHub runners
When an event that triggers a workflow is emitted, the defined jobs within the workflow get templated (using lazy templating) and are added to the job queue. Available GitHub runners that match the `runs-on` tag automatically pick up queued jobs and execute them on a fresh VM provisioned just for that job. The GitHub provided VMs come preinstalled with a [lot of tools](https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2204-Readme.md) to allow for fast execution of the jobs. It essentially runs shell commands directly on the host, even if the actual commands are abstracted by the GitHub Action modules. Each step gets individually templated, which allows users to pass values from one step or job to another using a special `GITHUB_OUTPUT` variable. These values do not have to be known before a job starts, they can be obtained and computed during job execution.  
The command outputs of jobs are streamed back to the GitHub instance, accessible via the GitHub UI in a shell-like output canvas. The output is near real-time, but the canvas can not be reliably searched via `Ctrl-F`.

### GitLab runners
The `.gitlab-ci.yml` gets fully templated and merged every time there is a CI triggering event. If the `rules` section of a job matches the triggering event, it gets added to the job queue. GitLab uses `tags` to specify an attribute or a list of attributes that the runner must have in order to run the job. An example would be `tags: [linux, large]`, where the runner must have at least these tags.  
GitLab's runners can have different executors, which determine how the user-defined job gets executed. The supported executors are Shell, SSH, VirtualBox, Docker, Kubernetes and [some more](https://docs.gitlab.com/runner/executors/). Each executor comes with some advantages and disadvantages. The Shell and SSH executors directly run on the specified machine. Users must make sure that every build dependency is either already installed on the machine or is included in the job script section. These executors change the host filesystem and are not idempotent, which can lead to a lack of reproducibility and unexpected behaviour. Therefore, the use of a virtualized executor is often preferred. Docker and Kubernetes use the container image specified in the `image` tag and run all scripts within that container. When the job is finished, the container gets deleted and the host system is in the same state as before.  
Currently, GitLab's SaaS runners use the `Docker+Machine` executor, a [GitLab maintained fork](https://gitlab.com/gitlab-org/ci-cd/docker-machine) of the deprecated Docker Machine project. These executors spawn new Google Cloud VMs with Docker installed to run the specified container image and execute all job scripts. At the time of writing, GitLab is working on replacing this executor with [an alternative](https://gitlab.com/gitlab-org/gitlab/-/issues/341856).  
While these executors are idempotent, they have some drawbacks when users want to perform some low-level system actions or need to use virtualisation themselves, resulting in nested virtualisation. Running container builds in the GitLab CI often requires the use of Docker in Docker, resulting in bind-mount of the Docker Socket and slower build performance, unless tools like *kaniko* or *buildah* are used. Variables between jobs can be passed to each other by writing them to a file and passing these artefacts between jobs.  
The script outputs are also sent back to the GitLab instance in periodic chunks. The resulting log in the UI is fully searchable. Other than GitHub, GitLab automatically downloads the Git repository at the ref specified in the event that triggered the job, unless it's explicitly turned off. If artefacts were defined in the job, they also get automatically up and downloaded. GitLab also offers a wider set of [predefined variables](https://docs.gitlab.com/ee/ci/variables/predefined_variables.html) that users can access while the jobs executes.

### Comparison
The execution of jobs is quite different between GitHub and GitLab. While the GitLab solution seems more complex at first glance, knowledge of its runner architecture is not required by developers. Only for GitLab admins who implement their own runners need to know the details in order to decide for an appropriate executor. Depending on the size of the organization, a simple Docker or Kubernetes executor should cover most use cases for a CI/CD runner. GitHub also allows users to bring their own, self-hosted runners, which just like GitLab will not be billed (at least not by GitHub/GitLab). Own runners allow for better confidentiality between own jobs and the jobs of others, have consistent performance and meet specific requirements such as CPU architecture and GPU support. It also allows overcoming network borders by placing the runner inside restricted network segments to allow for communication with services that are not publicly accessible. Own runners might also be needed to overcome latency issues, since currently both GitHub's and GitLab's runners are located in the US.  
GitHub's runners allow for more flexible usage by just being a VM that is owned by you during the duration of the job, while GitLab's runners might be orientated more towards one specific use case. GitLab's runners automatically check out the code and manage artefacts distribution for the user. If the right container image is chosen, there it literally no need to install anything since all tools are already the present in container.  
Both runners should be able to fulfil most requirements, users should just be aware of the respective limitations regarding location, availability, CPU architecture and other feature and properties like cost. It must be mentioned that self-hosted runners can run more than one job per host concurrently, depending on the configuration. Due to privacy concerns, this feature is not enabled for hosted/SaaS runners.  
A performance comparison is intentionally not part of this comparison, since there are too many variables and influences present for any meaningful results.

## Security and Secrets
Both GitHub and GitLab allow users to set variables and secrets that are then available in their CI/CD runtime. Both input types can be set at the instance, group/organization, project level, and even per registered deployment environment. Secrets are special variables that are considered confidential, these will be masked by the CI system if they are found in the output log. GitLab allows users with the appropriate permissions to view the value of a secret after it has been set, while GitHub never shows the value again. Regarding security, this makes no real difference, as anyone with access to the CI files can output the secrets when executing a job. While the secret values will be masked, this safety mechanism can easily be bypassed by reversing and base64 encoding the value before they get written to the log. Therefore, the general recommendation is the usage of short-lived tokens.  
For project-related resources, both CI systems use such a short-lived token to access the code stored in Git, upload artifacts or create releases. The `GITHUB_TOKEN` or GitLab's `CI_JOB_TOKEN` is only valid during the execution of the job. The permissions for these tokens can be limited. GitLab allows altering the permissions of users, they can be limited to a specific scope and certain actions. The `CI_JOB_TOKEN` will inherent the permissions of the user that triggered the CI job. However, when a CI job runs, this token is accessible, with its specific permissions, for all jobs and tasks within these jobs.  
GitHub on the other hand, allows for a more [fine-grained permission](https://docs.github.com/en/actions/security-guides/automatic-token-authentication#permissions-for-the-github_token) model for its token. These permissions can also be defined at the workflow or job level. Unlike GitLab, GitHub does not make its token accessible for every step in the CI flow by default. Creating a release via GitHub Actions requires access to the GitHub release API with a valid token, downloading public dependencies or compiling code does not require any tokens. Only steps that request access to the token or are explicitly given access via the `${{ secrets.GITHUB_TOKEN }}` parameter can use that token. The default untrustworthy approach makes a lot of sense since users are much more likely to use third-party actions in their CI, which is code written by strangers. Before the introduction of the GitLab CI/CD catalog, most CI code in GitLab was owned by the project owners or their organization.  
GitHub defaults to the least privilege solution with less trust at every step, where access can be given only if required. Organizations can enforce an even more permissive permission scope for the `GITHUB_TOKEN` and can also limit the allowed GitHub Actions to internal or whitelisted ones in order to meet company compliance policies. GitLab does not currently support such a feature out of the box. Instead, GitLab allows users to extend the permissions of its `CI_JOB_TOKEN` to access additional Git repositories. In a multi repository/microservice project, this results in a smaller number of user-managed tokens. To access multiple private repos in GitHub, users need to create their own token since the `GITHUB_TOKEN` currently does not support such a feature and is only valid for the current repository. 
Both services encourage the use of short-lived tokens or external secret solutions. GitLab has first-party support with HashiCorp Vault to use external secrets. Besides this, both GitHub and GitLab act as an *Identity-Provider* (IDP) to allow the usage of [OpenID Connect (OIDC)](https://openid.net/developers/how-connect-works/) to offer secure communication with the three major cloud providers using short-lived tokens. Depending on the configurations, this allows users to access and manage cloud resources in the CI/CD by using a trust relationship rather than any explicit credentials. GitLab builds this functionality directly into their CI/CD system, while GitHub relies on GitHub Actions like `configure-aws-credentials` or `azure-login`.  
A useful extra feature that GitLab does not have is the ability to add secret masks while the CI is already running. Especially when using short-lived access tokens, which the CI cannot know in advance, it is helpful to use `echo "::add-mask::MY_TOKEN"` to prevent unwanted exposure in logs. 

## Additional Functionality & Services
Running predefined tasks when a specific event is triggered is the core functionality of a CI/CD system, but requirements and competition in the CI/CD world are constantly increasing. Having functionality that makes the lives of developers easier might be a major selling point. These following functions were not considered in the previous comparison, but should be mentioned for a complete picture of GitHub Actions and GitLab CI.  
Both GitHub Actions and GitLab CI can run additional services besides the main CI tasks. These services are defined as containers that can offer a database or local web server within the CI job. This can allow users to run integration tests within the CI. A job can perform a database migration test on an ephemeral DB or an end-to-end test with playwright against a temporary hosted website, all within a CI job.  
Project documentation or a static website can be hosted on GitHub and GitLab using their *Pages* feature. Both CI/CD systems can build and directly deploy HTML sites to their page environments without the need for any extra authentication.  
To speed up tests and build jobs, both systems support caches. GitHub has official actions to upload and download caches, while GitLab offers the `cache` keyword and manages uploading and downloading caches as part of the job initialisation.  
When all test succeeded, software packages can be deployed to one or more environments. Both systems offer a `environment` keyword. Every job that references an environment creates a deployment in that environment. Environments can have their own set of variables and secrets to allow stricter separation between them for increased security. A link to a successful deployment is then shown on the repository or pull request UI. GitHub requires users to create environments beforehand. GitLab can dynamically create environments based on supplied variables, like the branch name. Furthermore, GitLab also has different actions for environments to create, access and delete them on demand. Environments can even be automatically removed after a certain time or after a pull request gets merged. Compared to GitHub, GitLab's environments are definitely more advanced and versatile. For Kubernetes users, GitLab offers its optional [GitLab Agent](https://docs.gitlab.com/ee/user/clusters/agent/) to access the insides of a cluster without any additional tokens. The agent gets deployed within a cluster and communicates with a GitLab instance, allowing it to be accessed via the CI.

## Overall Comparison
GitHub Actions and GitLab CI are two very powerful CI/CD systems that allow users to automate almost every imaginable task within the software development life cycle. At a functional level, both systems are on a similarly equal level, but the way they are implemented differs significantly.  
GitHub offers a stable, versatile and modular platform to run almost every kind of imaginable task. It integrates seamlessly with every one of GitHub's features. Where needed, it allows for integration with standard solutions, such as the ability to run containers or authenticate with third-party services over OIDC. It relies heavily on its vast marketplace of official and community actions, which do most of the actual work, such as checking out code, installing software, using caches or publishing releases. GitHub also gives fine-grained control over security-related settings, which can be enforced to be significantly more permissive than its competitor, GitLab.  
GitLab on the other hand, provides a much more managed solution for its users. It is part of the CI/CD system to check out code, manage caches and releases. It directly integrates with Vault and major cloud providers. GitLab itself also seems to allow for easier integration with third-party systems. CI triggers from external services like issue trackers and chat tools are much more versatile, just like the CI environment setup. But GitLab requires the user to write all the CI task implementations themselves. Sharing and reusing CI definitions becomes difficult and quickly confusing with the monolithic approach of one big `.gitlab-ci.yml` file approach. There are multiple levels of including, inherence and extending which can make it hard to get a quick oversight of what a job actually does. Eventually, this might get better with GitLab's new CI/CD catalog, but this is not guaranteed since components compare much more to GitHub's reusable workflows instead of individual actions. GitLab is definitely in the middle of a migration process regarding their CI, not just to allow it to be more reusable, but also to get rid of their `docker+machine` runners. In contrast to GitHub's modular approach, GitLab seems to have to deal with significantly more historical challenges due to its more managed approach. From a software engineering perspective, GitHub's design might be the more beneficial long-term position because their modular approach allows them to add features without many legacy impediments. 
There is no clear recommendation for one or the other system. Both are more than capable of running any imaginable task. The requirements for the actual development Platform, GitHub and GitLab, should be much more important than its CI features. Costs and data privacy, as well as the ability to self-host, are often more relevant factors than the differences between the CI/CD systems.


![OctoCar vs Octo Logo GitLab](https://i.imgur.com/b6THgdq.png)
