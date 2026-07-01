# Phase 3.1 & 3.2 — Docker Installation & Portainer Container Deployment

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

*`systemctl status docker` confirming the Docker daemon is `active (running)`, `enabled` for auto-start on boot, and fully initialised — including the final `API listen on /run/docker.sock` log entry confirming it's ready to receive commands.*

### Outcome

Docker Engine 29.1.3 is installed, running, enabled on boot, and accessible by `arsalanubuntu01` without root elevation. `LNX-SRV-01` is now a fully operational container host, ready for Phase 3.2.

---

## Phase 3.2 — Isolated Service Architecture (Portainer Container Deployment)

**Objective:** Deploy a production-used containerised application (Portainer CE) on `LNX-SRV-01`, demonstrating image pulling from a trusted registry, container lifecycle management, and the architectural separation between image (blueprint) and container (running instance).

### Why Portainer

Portainer Community Edition is a web-based Docker management dashboard used in real enterprise environments to visually manage containers, images, volumes, and networks. Deploying Portainer as the Phase 3 containerised service serves a dual purpose: it demonstrates genuine container deployment competency, while also providing a persistent management interface for all subsequent Docker work in this lab. It is an immediately recognisable tool to hiring managers in infrastructure and DevOps roles.

### What Was Done

- Deployed Portainer CE using `docker run` with the following configuration:
  - `-d` — detached mode, container runs in the background
  - `--name portainer` — human-readable container name
  - `--restart=always` — container auto-restarts on failure or VM reboot, equivalent to `systemctl enable` for a service
  - `-p 8000:8000` and `-p 9443:9443` — host-to-container port mappings exposing Portainer's web interface and agent communication port
  - `-v /var/run/docker.sock:/var/run/docker.sock` — mounts Docker's own control socket into the container, allowing Portainer to manage the host's Docker environment from inside a container
  - `-v portainer_data:/data` — named volume mount ensuring Portainer's configuration and data persists beyond the container's lifetime
- Docker automatically pulled the `portainer/portainer-ce:latest` image from Docker Hub on first run, downloading all required layers
- Completed initial Portainer setup via browser at `https://10.0.0.20:9443`, creating the admin account and supplying the setup token retrieved from container logs via `docker logs portainer`
- Connected Portainer to the local Docker environment, confirming full visibility of the running container, volume, and image

### The Image/Container Distinction

A Docker **image** is a read-only, layered filesystem snapshot — the blueprint. It carries the application code, libraries, and runtime dependencies needed to run, but is itself inert. A **container** is a live, running instance created from that image — it has its own isolated process space, network interface, and writable layer on top of the read-only image. Multiple containers can run from the same image simultaneously, each isolated from the others, each with their own independent state.

### Key Principles Demonstrated

- **Least privilege** — Portainer's web-serving worker processes run as a non-root user inside the container; root access is scoped only to the minimum required operations
- **Explicit-over-implicit** — every container capability (port exposure, volume access, socket access) is explicitly declared in the `docker run` command; nothing is granted by default
- **Blast radius containment** — Portainer runs inside an isolated container; a compromise of the application lands inside that container's boundaries, not directly on the host filesystem

### Evidence

![Phase 3.2 Portainer Image Pull Complete](Phase%203.2%20Portainer%20Image%20Pull%20Complete.png)

*Docker pulling the `portainer/portainer-ce:latest` image from Docker Hub, downloading all layers and confirming `Download complete` — demonstrating trusted registry image retrieval.*

![Phase 3.2 Portainer Dashboard Running](Phase%203.2%20Portainer%20Dashboard%20Running.png)

*Portainer dashboard confirming the local Docker environment is connected and `Up` — showing 1 running container, 1 volume, 1 image, and the host's 2 CPU / 3.5GB RAM resources correctly reported.*

### Outcome

Portainer CE is running as a containerised service on `LNX-SRV-01`, accessible via HTTPS at `https://10.0.0.20:9443`, fully connected to the local Docker environment, with persistent data storage via a named volume. Phase 3.1 and 3.2 are complete and verified end-to-end through a browser, not just terminal output.
