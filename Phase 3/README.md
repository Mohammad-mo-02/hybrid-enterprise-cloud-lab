# Phase 3 — Modern Microservices & Container Architectures

## Overview

Phase 3 transitions the lab from a manually-configured, single-service environment into a modern containerised infrastructure. Building directly on top of the hardened Ubuntu Server (`LNX-SRV-01`) established in Phase 2, this phase deploys Docker Engine as the container runtime and introduces a production-used containerised application (Portainer CE), persistent data storage via volume mounts, and Nginx reverse proxy routing — demonstrating the full container deployment lifecycle from image pull to browser-accessible service.

The phase concludes with Ansible configuration management, abstracting every manual hardening and deployment step from Phases 2 and 3 into a declarative, reusable playbook capable of rebuilding the entire environment automatically against a fresh machine.

## Why This Phase Matters

Containers are the dominant model for modern application deployment. Understanding Docker — images, containers, volumes, networking, and reverse proxy integration — is the foundational competency for DevOps, cloud, and infrastructure engineering roles. Phase 3 demonstrates this competency hands-on, in a hardened, production-realistic environment, not a tutorial sandbox.

## Sub-Phases

| Phase | Title | Summary |
|-------|-------|---------|
| 3.1 | Docker Installation | Docker Engine installed, verified running, user permissions configured |
| 3.2 | Portainer Container Deployment | Portainer CE deployed from Docker Hub, accessible via HTTPS dashboard |
| 3.3 | Data Lifecycle Engineering | Named volume persistence verified across container restarts |
| 3.4 | Nginx Reverse Proxy | Nginx reconfigured to route external traffic to containerised services |
| 3.5 | Ansible Configuration Management | Full environment automation via declarative Ansible playbook |

## Environment

- **Host:** `LNX-SRV-01` — Ubuntu Server 26.04 LTS, static IP `10.0.0.20`
- **Container Runtime:** Docker Engine 29.1.3
- **Containerised Service:** Portainer Community Edition 2.39.4 LTS
- **Access:** HTTPS via Nginx reverse proxy, SSH key-only access to host
