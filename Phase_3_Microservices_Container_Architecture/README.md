# Phase 3 — Modern Microservices & Container Architectures

---

## Overview

Phase 3 transitions the lab from a manually-configured, single-service environment into a modern containerised infrastructure. Building directly on top of the hardened Ubuntu Server (`LNX-SRV-01`) established in Phase 2, this phase deploys Docker Engine as the container runtime, introduces a production-used containerised application (Portainer CE), persistent data storage via volume mounts, and Nginx reverse proxy routing.

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

*Portainer dashboard loading immediately after restart — admin session intact, environment still `Up`. No setup page, no lost configuration — volume persistence confirmed.*

---

## Phase 3.4 — Advanced Network Redirection (Nginx Reverse Proxy)

**Objective:** Reconfigure Nginx from a direct file server into a reverse proxy, routing all incoming HTTPS traffic through to the Portainer container — making Nginx the single controlled entry point and keeping the container itself off the public-facing network.

### What Was Done

- Rewrote `/etc/nginx/sites-available/default` with two clean server blocks:
  - **Block 1 (Port 80):** Redirects all HTTP traffic to HTTPS via `return 301` — no plain-text connections accepted
  - **Block 2 (Port 443):** Receives HTTPS traffic and proxies it internally to Portainer on `localhost:9443` via `proxy_pass`
- Added required proxy headers (`Host`, `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto`) so Portainer receives accurate client information through the proxy layer
- Set `proxy_ssl_verify off` — instructs Nginx not to validate Portainer's self-signed certificate on the internal connection, since certificate trust is handled at the Nginx/client boundary, not internally
- Added `Nginx HTTPS` rule to UFW firewall to allow port 443 traffic through
- Validated config with `nginx -t` before applying — `syntax is ok / test is successful`
- Reloaded Nginx via `sudo systemctl reload nginx`
- Verified end-to-end: navigating to `https://10.0.0.20` (no port) loads Portainer dashboard directly through Nginx

### Why This Matters

Before this phase, Portainer was directly accessible on port 9443 — any client that could reach the machine could reach Portainer directly. After this phase, **Nginx is the only entry point**. Portainer's port is still mapped on the host, but all legitimate traffic flows through the hardened, TLS-terminating Nginx layer first. This is the same default-deny philosophy from Phase 2.6 applied at the application routing layer — one controlled, inspectable gateway, everything else behind it.

### Key Principles Demonstrated

- **Single controlled entry point** — Nginx acts as the sole gateway; containers are never directly exposed
- **Explicit-over-implicit** — every proxy header, SSL setting, and redirect is deliberately declared
- **Defence in depth** — TLS termination at Nginx + container isolation + host firewall = three independent layers

### Evidence

![Phase 3.4 Nginx Reverse Proxy Portainer](Phase%203.4%20Nginx%20Reverse%20Proxy%20Portainer.png)

*Portainer dashboard loading at `https://10.0.0.20` with no port number — confirming Nginx is successfully proxying all traffic through to the Portainer container on port 9443.*

### Outcome

Nginx is now functioning as a hardened reverse proxy. All traffic enters through port 443, is TLS-terminated by Nginx, and is forwarded internally to Portainer. The container is no longer directly network-exposed. Phase 3.4 complete and verified end-to-end through a browser.

---

# Phase 3.5 — Configuration Management Orchestration (Ansible)

**Objective:** Shift from manual, imperative configuration to declarative, code-driven configuration management — encoding every hardening and deployment step from Phases 2.6 through 3.1 into a single, reusable Ansible playbook capable of rebuilding the environment's baseline automatically against any fresh machine.

## The Philosophical Shift — Imperative vs Declarative

Everything done manually across this project so far has been **imperative**: issue commands in sequence, the machine does what you tell it, in the order you tell it. This works for one machine but doesn't scale, doesn't self-correct, and doesn't recover from configuration drift.

Ansible is **declarative**: instead of telling the machine what to do, you describe what the world should look like. Ansible determines what actions are needed to produce that state and only takes actions that are actually necessary. This produces **idempotency** — running the playbook ten times produces the same result every time, making no unnecessary changes if the desired state already exists.

## What Was Done

- Installed Ansible on `LNX-SRV-01` via `apt install ansible` — verified as `ansible core 2.20.1`
- Created `/home/arsalanubuntu01/ansible/site.yml` — a declarative playbook encoding the full baseline:
  - SSH hardening: `PasswordAuthentication no`, `PermitRootLogin no`
  - UFW firewall: default deny incoming, explicit allow for SSH/HTTP/HTTPS
  - Docker Engine: installed, running, enabled on boot, user added to docker group
  - Nginx: installed, running, enabled on boot
- Configured passwordless sudo for Ansible via `/etc/sudoers.d/ansible-nopasswd` — standard practice for Ansible managed nodes
- Executed playbook against localhost: `ansible-playbook site.yml -i "localhost," -c local`
- Executed playbook a second time to prove idempotency

## Playbook Results

**Run 1:** `ok=16 changed=4 failed=0` — Ansible enforced the desired state, making 4 necessary adjustments (SSH restart + 3 new UFW rules). All other components already in correct state.

**Run 2:** `ok=16 changed=1 failed=0` — Only the deliberate SSH restart task triggered. All 15 other tasks confirmed already in desired state, no changes made. Idempotency proven.

## Key Principles Demonstrated

- **Idempotency** — the playbook produces the same result on every run, making no unnecessary changes when the desired state already exists
- **Configuration drift elimination** — running this playbook against any machine that has diverged from baseline instantly restores it to the correct state
- **Declarative over imperative** — the playbook describes what the machine should look like, not the sequence of actions to get there
- **Infrastructure as Code** — the entire environment baseline is now version-controlled, auditable, and reproducible from a single file

## Evidence

![Phase 3.5 Ansible First Run](Phase%203.5%20Ansible%20First%20Run.png)

*First playbook execution — `ok=16 changed=4 failed=0`. Ansible enforced the full baseline state across SSH hardening, UFW firewall rules, Docker, and Nginx.*

![Phase 3.5 Ansible Idempotency Run](Phase%203.5%20Ansible%20Idempotency%20Run.png)

*Second playbook execution — `ok=16 changed=1 failed=0`. Only the deliberate SSH restart triggered. All 15 remaining tasks confirmed already in desired state — idempotency demonstrated.*

## Outcome

The entire `LNX-SRV-01` environment baseline — SSH hardening, firewall policy, Docker installation, and Nginx deployment — is now encoded as a declarative, version-controlled Ansible playbook. Running `ansible-playbook site.yml` against any fresh Ubuntu machine reproduces the full hardened baseline automatically, with zero manual intervention. Configuration drift can be eliminated instantly by re-running the playbook at any time.

