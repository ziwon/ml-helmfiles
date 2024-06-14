# ml-infra

## Overview

This repository provides a streamlined ML infrastructure environment using Minikube. It includes:
- Training the ResNet18 model on the MNIST dataset.
- Deploying the trained model for inference using Triton Inference Server.
- Kubernetes Helm charts to manage basic resources.
- Automation scripts to facilitate setup.

## Prerequisites

- **Minikube** installed on your local machine.
- **Podman** and **cri-o** installed and configured (instead of Docker).
- **Helm** and **Helmfile** installed.
- **Just** installed for task automation.

First, ensure Minikube is configured to use `cri-o` as the container runtime. Follow the setup instructions in the `Justfile` tasks.

## Project Structure

- `helmfile.yaml`: Root Helmfile to manage multiple Helm charts.
- `bases/`: Base configuration files.
- `releases/`: Release configurations for components like NFS, Ingress, Seldon Core, and training jobs.
- `charts/`: Helm charts and Python scripts for the ResNet18 training job and Triton client.
- `hack/`: Helper scripts for setting up the environment, including NFS, DNS, and Docker registry.
- `.env`, `.env.minikube`: Environment variable files.

## Usage

### Setting Up the Environment

1. **Install Podman and cri-o**

    ```sh
    just podman
    just crio
    ```

2. **Start Minikube**

    ```sh
    just k8s-up
    just k8s-down # if there's a problem
    ```

3. **Install NFS server and client**

    ```sh
    just nfs
    ```

4. **Update /etc/hosts on the host and Minikube, and patch Corefile of CoreDNS**

    ```sh
    just dns
    ```

5. **Prepare private registry on the host and crio in Minikube**

    ```sh
    just registry
    ```

### Building Containers

1. **Build the training job**

    ```sh
    just docker-build
    just docker-run
    just docker-push
    ```

2. **Build the Triton client**

    ```sh
    just docker-build triton-client
    just docker-run triton-client
    just docker-push triton-client
    ```

### Running the Setup

1. **Select the environment**

    ```sh
    just env minikube
    ```

2. **Deploy all Helm charts at once**

    ```sh
    just apply
    ```

3. **(Optional) Deploy Helm charts by label**

    ```sh
    just apply tier=common # Storage Class, Priority Class
    just apply tier=ops # NFS, Ingress
    just apply tier=ml # Seldon Core Operator, Triton Server
    just apply tier=train # Training Job
    just apply tier=client # Triton Client
    ```

## Future Works

- Automated CI/CD/CT Pipeline
- Drift Monitoring and Logging 
- Scalability Improvements using Seldon
- Model Versioning and Management using DVC
- MetalLB Integration to handle external traffic
- Distributed Training with Ray or DistributedBackend
