# Phase 3 — Modern Microservices & Container Architectures

---

## Overview

Phase 3 transitions the lab from a manually-configured, single-service environment into a modern containerised infrastructure. Building directly on top of the hardened Ubuntu Server (`LNX-SRV-01`) established in Phase 2, this phase deploys Docker Engine as the container runtime, introduces a production-used containerised application (Portainer CE), persistent data storage via volume mounts, and Nginx reverse proxy routing — demonstrating the full container deployment lifecycle from image pull to browser-accessible service.

The phase concludes with Ansible configuration management, abstracting every manual hardening and deployment step from Phases 2 and 3 into a declarative, reusable playbook capable of rebuilding the entire environment automatically against a fresh machine.

**Environment:**
- Host: `LNX-SRV-01` — Ubuntu Server 26.04 LTS, static IP `10.0.0.20`
- Container Runtime: Docker Engine 29.1.3
- Containerised Service: Portainer Community Edition 2.39.4 LTS
- Access: HTTPS via browser, SSH key-only access to host

---

## Phase 3.1 — Container Framework Deployment (Docker Installation)

**Objective:** Install and verify Docker Engine on `LNX-SRV-01`, establishing the container runtime that all subsequent Phase 3 work depends on.

### What Was Done

- Updated the local package index via `apt update` to ensure the latest available version was installed
- Installed Docker Engine via `apt install docker.io` — Ubuntu's packaged Docker distribution, pulling from the trusted Ubuntu repository
- Verified Docker daemon status via `systemctl status docker`, confirming `active (running)` and `enabled` — running immediately and configured to auto-start on boot
- Added `arsalanubuntu01` to the `docker` group via `usermod -aG docker`, removing the requirement to prefix every Docker command with `sudo` — the daemon runs as root, but group membership grants the user permission to communicate with it directly
- Applied group membership to the current session immediately via `newgrp docker`, avoiding a full logout/login cycle
- Confirmed Docker CLI responding correctly via `docker --version` → `Docker version 29.1.3`

### Architecture Note

Docker operates on a client/server model: the **Docker daemon** (`dockerd`) runs continuously as a background service managed by `systemctl`, doing the actual work of building, running, and managing containers. The **Docker CLI** is the command-line tool the user interacts with, sending instructions to the daemon via a Unix socket (`/var/run/docker.sock`). Every `docker` command typed in the terminal is a client call to that daemon — which is why group membership matters: without it, the socket is root-only and every command requires `sudo`.

### Key Principle Demonstrated

**Least privilege** — rather than running all Docker commands as root, group membership grants precisely the access needed (daemon communication) without elevating the user's broader system permissions.

### Evidence

![Phase 3.1 Docker Active Running](Phase%203.1%20Docker%20Active%20Running.png)

*`systemctl status docker` confirming the Docker daemon is `active (running)`, `enabled` for auto-start on boot, and fully initialised.*

---

## Phase 3.2 — Isolated Service Architecture (Portainer Container Deployment)

**Objective:** Deploy a production-used containerised application (Portainer CE) on `LNX-SRV-01`, demonstrating image pulling from a trusted registry, container lifecycle management, and the architectural separation between image (blueprint) and container (running instance).

### Why Portainer

Portainer Community Edition is a web-based Docker management dashboard used in real enterprise environments to visually manage containers, images, volumes, and networks. It is an immediately recognisable tool to hiring managers in infrastructure and DevOps roles, and its deployment here demonstrates genuine container competency backed by a visually demonstrable, browser-accessible result.

### What Was Done

- Deployed Portainer CE using `docker run` with the following configuration:
  - `-d` — detached mode, container runs in the background
  - `--name portainer` — human-readable container name
  - `--restart=always` — container auto-restarts on failure or VM reboot
  - `-p 8000:8000` and `-p 9443:9443` — host-to-container port mappings
  - `-v /var/run/docker.sock:/var/run/docker.sock` — mounts Docker's control socket into the container, allowing Portainer to manage the host's Docker environment from inside a container
  - `-v portainer_data:/data` — named volume mount ensuring Portainer's data persists beyond the container's lifetime
- Docker automatically pulled the `portainer/portainer-ce:latest` image from Docker Hub
- Completed initial setup via browser at `https://10.0.0.20:9443`, creating admin account using setup token retrieved from `docker logs portainer`
- Connected Portainer to the local Docker environment, confirming full visibility of running container, volume, and image

### Key Principles Demonstrated

- **Explicit-over-implicit** — every container capability (port exposure, volume access, socket access) is explicitly declared; nothing granted by default
- **Blast radius containment** — a compromise of the application lands inside the container's boundaries, not directly on the host filesystem

### Evidence

![Phase 3.2 Portainer Image Pull Complete](Phase%203.2%20Portainer%20Image%20Pull%20Complete.png)

*Docker pulling the `portainer/portainer-ce:latest` image from Docker Hub, all layers downloading successfully.*

![Phase 3.2 Portainer Dashboard Running](Phase%203.2%20Portainer%20Dashboard%20Running.png)

*Portainer dashboard confirming local Docker environment connected and `Up` — 1 container, 1 volume, 1 image, 2 CPU / 3.5GB RAM correctly reported.*

---

## Phase 3.3 — Data Lifecycle Engineering (Volume Persistence)

**Objective:** Verify that containerised application data persists across container restarts, demonstrating that the named volume mount correctly decouples application state from the container's ephemeral lifecycle.

### What Was Done

- Confirmed `portainer_data` named volume exists on the host via `docker volume ls`
- Restarted the Portainer container via `docker restart portainer` — a deliberate stop-and-start cycle to test data survival
- Confirmed container returned to running state via `docker ps` — `Up 8 seconds`, ports correctly mapped
- Navigated to `https://10.0.0.20:9443` immediately after restart — landed directly on the Portainer dashboard without being prompted for setup or re-authentication, confirming admin account and all configuration survived the restart intact

### Why This Matters

A container deployment without volume persistence is not production-ready — it loses all accumulated state on every restart. Demonstrating volume persistence proves understanding of the difference between deploying a container and deploying a container correctly.

### Key Principle Demonstrated

**Explicit-over-implicit** — the volume mount was a deliberate, explicitly declared choice. Nothing about Docker's default behaviour would have persisted this data without that declaration — silence means ephemeral, not persistent.

### Evidence

![Phase 3.3 Volume Persistence Docker PS](Phase%203.3%20Volume%20Persistence%20Docker%20PS.png)

*`docker volume ls` confirming `portainer_data` exists, followed by `docker restart portainer` and `docker ps` showing container back `Up 8 seconds` after restart.*

![Phase 3.3 Volume Persistence Dashboard After Restart](Phase%203.3%20Volume%20Persistence%20Dashboard%20After%20Restart.png)

*Portainer dashboard loading immediately after restart — admin session intact, environment still `Up`, timestamp confirming freshly restarted instance. No setup page, no lost configuration — volume persistence confirmed.*

---

## Phase 3.4 — Advanced Network Redirection (Nginx Reverse Proxy)

*In progress*

---

## Phase 3.5 — Configuration Management Orchestration (Ansible)

*In progress*
