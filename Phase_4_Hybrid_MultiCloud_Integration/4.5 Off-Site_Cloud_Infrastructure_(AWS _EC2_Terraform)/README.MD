# Phase 4.5 — AWS VPC, Bastion Host & Private Windows Server (Terraform)

**Project:** Hybrid Enterprise & Multi-Cloud Automation Lab
**Region:** `eu-west-2` (London) · **Account:** `819004394298`
**Tooling:** Terraform + AWS CLI on a Windows host, authenticated via a named CLI profile (`arsalan-lab`)
**Status:** ✅ Built, verified end-to-end (RDP into a private server through a bastion), then destroyed for cost control. 100% reproducible from code.

> **How to use this document:** Parts 1–2 teach the underlying concepts from first principles.
> Part 3 onward applies them to this exact build. Read top-to-bottom the first time; after that use
> it as a reference. Every technical term is defined in the **Glossary** (Part 13).

---

## Part 1 — Foundations (the concepts, from zero)

### 1.1 What is a VPC?
A **VPC (Virtual Private Cloud)** is your own private, logically-isolated network *inside* AWS. Think
of it as a fenced plot of land with a building on it: everything you run (servers, databases) lives
inside, and nothing from outside gets in unless you explicitly allow it. Two AWS customers' VPCs
cannot see each other. It is the direct cloud equivalent of the isolated host-only network used for
the on-prem side of this lab.

### 1.2 IP addressing and CIDR (why `10.20.0.0/16`)
Every machine on a network needs an **IP address** (e.g. `10.20.11.137`). A network is described by a
**CIDR block** — an address range written as `base/prefix`:

- The **prefix** (`/16`, `/24`) says how many bits are fixed as the "network" part. The remaining bits
  are free for hosts.
- `10.20.0.0/16` fixes the first 16 bits (`10.20`), leaving 16 bits for hosts → **2¹⁶ = 65,536**
  addresses (`10.20.0.0` … `10.20.255.255`).
- `10.20.1.0/24` fixes 24 bits, leaving 8 → **2⁸ = 256** addresses (`10.20.1.0` … `10.20.1.255`).

**Subnetting** = carving the big VPC range into smaller subnet ranges. We split the `/16` into four
`/24`s. In AWS, each subnet loses **5 reserved addresses** (network address, VPC router, DNS, a
reserved slot, and broadcast), so a `/24` gives **251 usable** IPs.

> We deliberately chose `10.20.x` (not the common `10.0.x`) so this network never *overlaps* the
> on-prem lab. Overlapping ranges can never be joined later by VPN or peering — the routing becomes
> ambiguous. **Design address space with future connectivity in mind.**

### 1.3 Subnets: public vs private
A **subnet** is a slice of the VPC that lives in one Availability Zone. There is nothing intrinsically
"public" or "private" about a subnet — the label depends **entirely on its route table** (see 1.4):

- **Public subnet** = its route table has a route to the **Internet Gateway**.
- **Private subnet** = its route table has **no** route to the Internet Gateway (only, at most, an
  outbound route via a NAT).

### 1.4 Route tables (the single most important concept)
A **route table** is a list of rules: *"traffic destined for range X → send to target Y."* When a
packet leaves an instance, AWS picks the **most specific matching route** (longest-prefix match):

| Destination | Target | Meaning |
|---|---|---|
| `10.20.0.0/16` | `local` | "Anything inside the VPC — deliver directly." Automatic; every route table has it and it can't be removed. |
| `0.0.0.0/0` | IGW **or** NAT | "Everything else (the whole internet) — send here." This is the **default route**. |

`0.0.0.0/0` means "all addresses." Whether that default route points at the **IGW** (public) or the
**NAT** (private) is *literally what makes a subnet public or private*. **The absence of an IGW route
is the security boundary** — there is no path in, so nothing external can reach the instance.

### 1.5 Internet Gateway (IGW)
The **IGW** is a horizontally-scaled, highly-available component attached to the VPC. It is the single
door between the VPC and the public internet. It also performs **1:1 NAT** for instances that have a
public IP: it translates the instance's private IP ⇄ its public IP so return traffic finds its way
back. Only subnets whose route table points `0.0.0.0/0` at the IGW can use it.

### 1.6 NAT Gateway (and why it's outbound-only)
A **NAT (Network Address Translation) Gateway** lets instances in a **private** subnet reach the
internet **outbound only** — for OS updates, downloading agents, etc. — while blocking any
**inbound-initiated** connection.

How it works: the NAT lives in a *public* subnet and has a fixed public address (an **Elastic IP**).
When a private instance sends a packet out, the NAT rewrites the **source** address from the
instance's private IP to the NAT's public IP (**source NAT / SNAT**) and remembers the connection.
Reply packets are matched to that remembered connection and allowed back. But because *the outside
world never sees the private instance and can't start a new connection through the NAT*, inbound
attacks are impossible. It is a one-way outbound valve — the cloud twin of a home router's NAT.

### 1.7 Availability Zones and Regions
A **Region** (e.g. `eu-west-2`, London) is a geographic area. Inside it are multiple **Availability
Zones (AZs)** — physically separate data centres with independent power/cooling/networking, linked by
low-latency fibre. Spreading subnets across **two AZs** means a single data-centre failure doesn't
take everything down. This is **eliminating a single point of failure**.

### 1.8 Security groups (instance firewalls)
A **security group (SG)** is a firewall wrapped around an instance's network interface. Key properties:

- **Deny-by-default:** nothing is allowed unless a rule permits it.
- **Allow-only:** you can only write *allow* rules (no explicit deny).
- **Stateful:** if you allow a connection *in*, the reply is automatically allowed *out* (and vice
  versa) — you don't write return rules.
- **Referenceable:** a rule's source can be *another security group* rather than an IP range. We use
  this so the Windows SG allows RDP **from the bastion's SG**, not from any IP.

> **Advanced contrast — NACLs.** A **Network ACL** is a *subnet-level*, **stateless** firewall with
> ordered allow *and* deny rules. Stateless means you must allow both directions explicitly. We rely
> on the default NACL (allow-all) and do our filtering with SGs — the common pattern. Knowing the SG
> (stateful, instance-level) vs NACL (stateless, subnet-level) distinction is a frequent interview
> question.

### 1.9 The bastion host pattern
A **bastion** (or "jump host") is a single, hardened, monitored machine that is the *only* way to
reach private servers. Instead of exposing every server's management port to the internet, you expose
**one** small box, lock it down hard (key-only SSH, restricted source IP), and route all admin access
through it. It shrinks the attack surface to a single, watchable door.

### 1.10 SSH keys (asymmetric cryptography)
SSH key auth uses a **key pair**: a **public key** (a lock you place on the server) and a **private
key** (the only thing that opens it, kept on your machine). At login the server challenges the client
to prove it holds the matching private key — without the key ever being sent. This is far stronger
than passwords (nothing guessable, nothing to brute-force). The bastion accepts **key-based auth
only**.

### 1.11 SSH tunnelling / port forwarding (how we reached Windows)
The Windows server has no public IP, so we can't RDP to it directly. Instead we use **SSH local port
forwarding**:

```
ssh -L 13389:10.20.11.137:3389 ec2-user@<bastion-public-ip>
```

This tells SSH: *"open port `13389` on my laptop; anything sent there, carry it through the encrypted
SSH connection to the bastion, and from the bastion open a connection to `10.20.11.137:3389`."* We
then point Remote Desktop at `localhost:13389`, and it emerges inside the VPC at the Windows server's
RDP port — all wrapped in SSH. The Windows RDP port is **never** exposed to the internet.

### 1.12 EC2, AMIs, and the Windows password flow
- **EC2 (Elastic Compute Cloud)** = virtual servers ("instances").
- **AMI (Amazon Machine Image)** = the template (OS + config) an instance boots from. We look up the
  *newest* official Amazon Linux 2023 and Windows Server 2022 AMIs at build time, so no image ID is
  hard-coded or stale.
- **Instance type** `t3.micro` = a small burstable size (2 vCPU, 1 GiB RAM). Free-Tier eligible;
  crucially, AWS Free Tier grants 750 hrs/month of Linux **and** 750 hrs of Windows *separately*, so a
  Linux bastion + a Windows server both fit.
- **Windows admin password flow:** at first boot, EC2 generates a random Administrator password and
  **encrypts it with the key pair's public key**. You retrieve the encrypted blob and **decrypt it
  locally with your private key** (`aws ec2 get-password-data --priv-launch-key`). The password never
  travels in the clear. (Note: AWS's decryption needs the private key in **PEM/RSA** format — see
  Gotchas.)

---

## Part 2 — Infrastructure as Code & Terraform

### 2.1 Declarative vs imperative
**Imperative** = you list the steps ("click this, then that"). **Declarative** = you describe the
*desired end state*, and the tool works out the steps. Terraform is declarative: you say "I want a VPC
with these subnets," and Terraform figures out what to create, in what order.

### 2.2 Core Terraform pieces
- **Provider** — a plugin that translates Terraform into a specific platform's API (here, `aws`).
- **Resource** — a thing to create/manage (`aws_vpc`, `aws_instance`, …).
- **Data source** — a *read-only lookup* of something that already exists (we use it to find the
  latest AMIs). It creates nothing.
- **Variable** — a named input (region, CIDRs, your IP), defined once and reused.
- **Output** — a value Terraform prints after building (e.g. the bastion's public IP).
- **State file** (`terraform.tfstate`) — Terraform's record of what it has built and each resource's
  real-world ID, so it knows what already exists. **It can contain sensitive values → never commit it
  to git.**

### 2.3 The lifecycle: init → plan → apply → destroy
- `terraform init` — downloads the provider plugin; one-time per project.
- `terraform plan` — a **dry run**: compares your code to reality and prints exactly what it *would*
  change, creating nothing. This is *review-before-execute*.
- `terraform apply` — makes reality match the code (asks you to type `yes`).
- `terraform destroy` — removes everything it created (cost control + clean teardown).

### 2.4 Idempotency and the dependency graph
**Idempotent** means running the same code repeatedly always converges on the same result — apply
twice and the second run says "no changes." That's why we can `destroy` at night and `apply` in the
morning and get an *identical* environment. Terraform also builds a **dependency graph**: because
`aws_subnet` references `aws_vpc.main.id`, Terraform knows the VPC must exist first. Where there's no
natural reference, we add `depends_on` (e.g. the NAT depends on the IGW). This is
**explicit-over-implicit** ordering.

---

## Part 3 — This build's architecture

![Architecture diagram](architecture.svg)

*(Your own `design` screenshot of this diagram is included as evidence — see Part 8.)*

| Component | Value / setting | Why |
|---|---|---|
| **VPC** | `10.20.0.0/16`, DNS enabled | Isolated private network; DNS lets instances resolve names |
| **Public subnet A** | `10.20.1.0/24`, AZ `eu-west-2a` | Holds the bastion + NAT; routes to IGW |
| **Public subnet B** | `10.20.2.0/24`, AZ `eu-west-2b` | Multi-AZ capacity (reserved) |
| **Private subnet A** | `10.20.11.0/24`, AZ `eu-west-2a` | Holds the Windows server; routes to NAT only |
| **Private subnet B** | `10.20.12.0/24`, AZ `eu-west-2b` | Multi-AZ capacity (reserved) |
| **Internet Gateway** | attached to VPC | The one internet door for public subnets |
| **NAT Gateway + EIP** | in public subnet A | Outbound-only internet for private subnets |
| **Public route table** | `0.0.0.0/0 → IGW`, assoc. both public subnets | Makes them public |
| **Private route table** | `0.0.0.0/0 → NAT`, assoc. both private subnets | Outbound-only; **no IGW route** |
| **Bastion** | Amazon Linux 2023, `t3.micro`, public subnet, public IP | Single hardened entry point |
| **Windows server** | Windows Server 2022, `t3.micro`, private subnet, **no public IP** | The protected target |
| **Bastion SG** | inbound SSH(22) from **my IP /32** only | Least-privilege admin access |
| **Windows SG** | inbound RDP(3389) from **bastion SG** only | No internet path to the server |

**Total: 19 resources** — 14 network (1 VPC, 4 subnets, 1 IGW, 1 EIP, 1 NAT, 2 route tables,
4 associations) + 5 compute (1 key pair, 2 SGs, 2 instances).

---

## Part 4 — The code, file by file

The Terraform is split into small, purpose-named files so the folder itself is the map.

| File | Represents | What it declares / key arguments |
|---|---|---|
| `versions.tf` | Tool + plugin versions | `required_version`, AWS provider `~> 5.0` |
| `provider.tf` | How to reach AWS | region, `profile = "arsalan-lab"`, `default_tags` (auto-tags every resource for cost tracking) |
| `variables.tf` / `variables-compute.tf` | Inputs | CIDRs, AZs, region, `my_ip_cidr`, `instance_type`, key path |
| `terraform.tfvars` | Local values (git-ignored) | `my_ip_cidr = "<your IP>/32"` — keeps your IP out of git |
| `vpc.tf` | The building | `aws_vpc` with `enable_dns_support/hostnames = true` |
| `subnets.tf` | The rooms | 4 × `aws_subnet`; public ones set `map_public_ip_on_launch = true` |
| `gateways.tf` | The doors | `aws_internet_gateway`, `aws_eip` (domain `vpc`), `aws_nat_gateway` (in public subnet A, `depends_on` IGW) |
| `routes.tf` | The signs | 2 × `aws_route_table` (public→IGW, private→NAT) + 4 × `aws_route_table_association` |
| `keypair.tf` | SSH trust | `aws_key_pair` — uploads only the **public** key |
| `amis.tf` | OS image lookups | 2 × `data "aws_ami"` (newest AL2023 + Windows 2022) |
| `security-groups.tf` | The door locks | `bastion-sg` (SSH from my IP), `windows-sg` (RDP from bastion SG) |
| `bastion.tf` | Guarded entrance | `aws_instance` in public subnet, `associate_public_ip_address = true` |
| `windows.tf` | Private server | `aws_instance` in private subnet, **no** public IP argument |
| `outputs.tf` / `outputs-compute.tf` | Handy values | VPC/subnet IDs, bastion public IP, Windows private IP, ready-made SSH command |

---

## Part 5 — How traffic actually flows

**Admin inbound (me → the private server):**
1. From my laptop I SSH to the **bastion's public IP**. The bastion SG allows SSH **only from my
   /32**, and only my private key opens it. ✅
2. Through that SSH session I forward a local port to `windows-private-ip:3389`.
3. The bastion opens a connection to the Windows server on RDP(3389). The Windows SG allows RDP
   **only from the bastion SG** — the bastion qualifies. ✅
4. My Remote Desktop (pointed at `localhost:13389`) now controls the private server. At **no point**
   is anything on the Windows box reachable from the open internet.

**Private outbound (server → internet, e.g. updates):**
1. The Windows server sends a packet to the internet. Its route table's default route is
   `0.0.0.0/0 → NAT`.
2. The NAT (in the public subnet) rewrites the source to its Elastic IP and forwards via the IGW.
3. Replies return to the NAT, which maps them back to the server. **New inbound** connections cannot
   be started this way — outbound-only.

**Why inbound-from-internet is impossible for the server:** it has no public IP, and its subnet's
route table has **no route to the IGW**. There is simply no path.

---

## Part 6 — Security analysis (the four questions)

For each key component: *what is it? what can reach it? what's the boundary/blast radius? what
happens if it fails?*

**Bastion host**
- *What can reach it:* only my IP, only on SSH, only with my key.
- *Blast radius if compromised:* an attacker would still need my private key; even then they reach
  only what the bastion can (the private server's RDP) — not the whole VPC. Its SG is the limit.
- *If it fails:* I lose admin access until it's replaced (rebuild from code) — but nothing is exposed.

**Windows server**
- *What can reach it:* only the bastion, only on RDP. Nothing from the internet.
- *Blast radius:* it has no inbound internet path and outbound only via NAT, so a compromise can't be
  reached or easily exfiltrate inbound-initiated.
- *If it fails:* rebuild from code; no data of value in this lab.

**NAT Gateway** — *if it fails:* private instances lose outbound internet (patching stops) but stay
protected. A safe failure mode.

**Internet Gateway** — the one internet door; if detached the whole VPC goes dark to the internet
(safe-fail, not an exposure).

**Attack surface summary:** exactly **two** things face the internet — the IGW (a managed AWS service)
and the bastion's SSH port, which is locked to a single IP. Everything else is private.

---

## Part 7 — What we did (build log)

**Foundations (Phase 1.5):** created the AWS account; secured **root** with MFA and created **no root
access keys**; created a least-privilege IAM user (`arsalan-admin`) in an `Admins` group with its own
MFA and a CLI access key; installed Terraform + AWS CLI; configured the `arsalan-lab` profile;
verified with `aws sts get-caller-identity` (correct account, `user/arsalan-admin`, not root).

**Day 1 — network:** designed on paper first; walked the console VPC wizard only to *see* the pieces
(built nothing); wrote the network Terraform; `init` → `plan` (reviewed `14 to add`) → `apply`
(14 added); **verified** the private route table shows `0.0.0.0/0 → NAT` and no IGW route;
`destroy` to avoid overnight NAT cost.

**Day 2 — compute + proof:** `apply` rebuilt the identical network in ~90 s (idempotency proof);
generated an SSH key pair and locked SSH to my IP; wrote and `apply`-ed the compute layer (5 added);
SSH'd into the bastion; retrieved + decrypted the Windows password with the private key; opened an
SSH tunnel through the bastion; **RDP'd into the private Windows server** — full path proven; then
`destroy`.

---

## Part 8 — Evidence

Save these screenshots into `evidence/` with the exact names shown.

| # | File | Proves |
|---|---|---|
| 00 | `evidence/00-architecture-design.png` | The architecture diagram (your `design` screenshot) — the intended design |
| 01 | `evidence/01-terraform-init.png` | Project initialised (AWS provider downloaded) |
| 02 | `evidence/02-terraform-plan.png` | `Plan: 14 to add` reviewed before apply; VPC `10.20.0.0/16` |
| 03 | `evidence/03-terraform-apply-network.png` | `Apply complete! 14 added` — network built from code |
| 04 | `evidence/04-route-table-private-nat.png` | **Key proof:** private route table = `0.0.0.0/0 → NAT`, `10.20.0.0/16 → local`, **no IGW route** |
| 05 | `evidence/05-terraform-apply-compute.png` | `Apply complete! 5 added`; Windows **private** IP `10.20.11.137` |
| 06 | `evidence/06-ssh-into-bastion.png` | Logged into the bastion over SSH |
| 07 | `evidence/07-rdp-windows-desktop.png` | **Headline:** the private Windows desktop, reached only via the bastion tunnel |

---

## Part 9 — Design rationale & trade-offs

- **Custom VPC, not the default** — the default VPC is flat and all-public; a custom one gives explicit
  control of the public/private boundary and routing.
- **Server has no public IP** — removes the entire internet-facing attack surface; admin funnels
  through one hardened host.
- **Linux bastion (not Windows)** — mirrors the project's SSH-hardening approach *and* keeps both
  machines inside Free Tier (separate 750-hr Linux and Windows allowances). Trade-off: reaching a
  Windows target needs an SSH-tunnel rather than a direct RDP jump — a worthwhile skill.
- **Single NAT Gateway** — one NAT instead of one-per-AZ to control cost (~$0.045/hr). **Documented
  risk:** if AZ-a fails, AZ-b's private instances lose outbound internet. Acceptable for a lab; in
  production you'd run one NAT per AZ.

**Principles demonstrated:** least privilege · defence in depth · single hardened entry point ·
no insecure defaults · explicit-over-implicit · reproducibility (plan → apply → destroy).

---

## Part 10 — Gotchas & troubleshooting (things we actually hit)

- **SSH key format — "Unable to decrypt password data":** modern `ssh-keygen` writes keys in
  **OpenSSH** format, but AWS's Windows-password decryption needs **PEM (RSA)**. Fix:
  `ssh-keygen -p -m PEM -f <key>` (or generate with `-m PEM` up front). Same key material, different
  on-disk encoding.
- **Security-group naming — "cannot begin with sg-":** the `name` of an `aws_security_group` can't
  start with `sg-` (reserved for SG IDs). Renamed to `bastion-sg` / `windows-sg`.
- **RDP "can't connect":** almost always (a) wrong tunnel port (it's `13389`, not `13398`), or (b) the
  tunnel window was closed — the `ssh -L …` session *is* the pipe and must stay open.
- **Login rejected:** use `.\Administrator` (the leading `.\` forces the *local* account on the remote
  server, not your Microsoft/domain account).

---

## Part 11 — Rebuild / tear down & cost

```powershell
cd C:\Lab_Infrastructure\Terraform-Phase4.5-VPC
terraform init      # once per machine
terraform plan      # review (builds nothing)
terraform apply     # "yes" — builds all 19 resources (~2 min)
terraform destroy   # "yes" — removes everything, stops billing
```

**Cost:** instances are Free-Tier `t3.micro`. The **NAT Gateway is not free** (~$0.045/hr + data), so
always `destroy` when finished. This build was destroyed after verification → net cost pennies.

---

## Part 12 — Interview questions & model answers

**Q: Walk me through securely administering a server with no public internet access.**
> It sits in a private subnet with no public IP and no route to the internet gateway, so nothing
> external can reach it. I administer it through a bastion in a public subnet that only accepts SSH
> from my IP with key-based auth, then tunnel RDP through that SSH connection. All access funnels
> through one hardened, monitored entry point — defence in depth plus least privilege.

**Q: What actually makes a subnet public or private?**
> Its route table. A public subnet routes `0.0.0.0/0` to the Internet Gateway; a private subnet has no
> such route and only routes outbound via a NAT. The absence of the IGW route is the boundary.

**Q: IGW vs NAT Gateway?**
> The IGW is the two-way internet door for public subnets and does 1:1 NAT for public-IP instances.
> The NAT gives private instances outbound-only access via source NAT; nothing on the internet can
> initiate a connection inward through it.

**Q: Security group vs NACL?**
> Security groups are stateful, instance-level, allow-only. NACLs are stateless, subnet-level, with
> ordered allow and deny rules. I do filtering with SGs and leave the default allow-all NACL.

**Q: Why one NAT and what's the trade-off?**
> Cost — a NAT bills per hour. One NAT means an AZ-a failure cuts AZ-b's outbound internet; production
> would use one NAT per AZ. I documented the trade-off deliberately.

**Q: Why Infrastructure as Code?**
> Declarative, version-controlled, idempotent. I `plan` before I `apply`, `destroy` and rebuild
> identically to control cost, and get a reproducible, drift-free environment.

**Q: How did you keep it least-privilege?**
> IAM user instead of root, MFA everywhere, SSH from my IP only, RDP from the bastion SG only, and
> secrets (state, tfvars) kept out of source control.

---

## Part 13 — Glossary

- **VPC** — your isolated virtual network in AWS.
- **CIDR** — `base/prefix` notation for an address range (`/16` = 65,536, `/24` = 256).
- **Subnet** — a slice of the VPC in one AZ; public or private by its route table.
- **Route table** — rules mapping destination ranges to targets; decides public vs private.
- **Internet Gateway (IGW)** — the VPC's door to the internet; also does 1:1 NAT for public IPs.
- **NAT Gateway** — outbound-only internet for private subnets via source NAT; needs an Elastic IP.
- **Elastic IP (EIP)** — a static public IPv4 address.
- **Availability Zone (AZ)** — an isolated data centre within a region.
- **Security Group (SG)** — stateful, instance-level, allow-only firewall.
- **NACL** — stateless, subnet-level firewall with allow/deny rules.
- **Bastion host** — a single hardened jump box; the only admin entry to private servers.
- **EC2 / AMI / instance type** — virtual servers / their OS template / their size (`t3.micro`).
- **SSH key pair** — public key (on the server) + private key (on you) for password-less login.
- **SSH local port forwarding (`-L`)** — tunnels a local port through SSH to a target host:port.
- **Terraform** — declarative IaC tool: providers, resources, data sources, variables, outputs, state.
- **Idempotent** — running the same code repeatedly converges on the same result.
