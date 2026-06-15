# Hybrid Enterprise Infrastructure & Multi-Cloud Automation Lab

**Author:** Mohammad  
**Background:** MSc in Cybersecurity, University of Bradford  
**Target Jobs:** Systems Administrator | Cloud Support Engineer | Infrastructure Engineer  
**Target Region:** Greater Manchester / Bolton, UK  

---

## What Is This Project?

I'm building a complete enterprise IT environment on my own computer. This isn't a tutorial – it's me learning by doing.

A real business needs servers, user accounts, security policies, cloud storage, and automated processes. This lab covers all of that. I'm setting it up from scratch so I can understand how it actually works when I'm working in IT teams.

By the end of this, I'll have:
- A virtual data center (isolated on my computer)
- Active Directory for user management
- Hardened web servers on both Windows and Linux
- Cloud integration with AWS and Microsoft 365
- Infrastructure automation using PowerShell and Terraform
- Security hardening throughout (TLS, SSH key-pairs, Zero Trust)

---

## Why I'm Building This

Most jobs want people with hands-on experience. Reading documentation or watching tutorials isn't the same as actually building something and troubleshooting when it breaks. This lab is real, messy, and practical.

When I interview for roles in Manchester, I can show employers what I've actually built and how I solved problems. That's much stronger than theoretical knowledge.

---

## How This Is Organized

I'm building this in 6 phases:

**Phase 1:** Set up the virtualization (creating an isolated lab environment on my computer)  
**Phase 2:** Build Active Directory, user management, and hardened web servers  
**Phase 3:** Add containerization with Docker  
**Phase 4:** Connect to the cloud (AWS, Microsoft 365)  
**Phase 5:** Build automated workflows and governance  
**Phase 6:** Document everything using ITIL standards  

## Technologies I'm Using

| Layer | Technology | What It Does |
|-------|-----------|--------------|
| **Virtualization** | VMware Workstation Pro | Runs multiple VMs on my computer in isolation |
| **On-Prem OS** | Windows Server 2022 | Domain controller for user management |
| **On-Prem OS** | Ubuntu Server 22.04 LTS | Linux infrastructure & containerization |
| **Client OS** | Windows 11 Enterprise | Workstation for testing domain features |
| **User Management** | Active Directory (AD DS) | On-premises identity & access control |
| **User Management** | Fine-Grained Password Policies (FGPP) | Advanced security policies for admin accounts |
| **Web Servers** | IIS (Windows) | Windows web hosting with TLS hardening |
| **Web Servers** | Nginx (Linux) | Linux web hosting with reverse-proxy capability |
| **Certificates** | OpenSSL | Generate & manage SSL/TLS certificates |
| **Cloud Identity** | Microsoft Entra ID | Sync on-premises users to cloud |
| **Cloud Identity** | Entra Connect | Bridge between on-prem AD and Entra ID |
| **Endpoint Control** | Microsoft Intune | Enforce security policies on devices |
| **Cloud Access** | Zero Trust Conditional Access | Phishing-resistant MFA & location blocking |
| **Containers** | Docker Engine | Containerize & deploy microservices |
| **Reverse Proxy** | Nginx (as proxy) | Route container traffic securely |
| **Cloud Compute** | AWS EC2 | Cloud servers for off-site infrastructure |
| **Cloud Storage** | AWS S3 | Encrypted object storage with lifecycle rules |
| **Cloud Security** | AWS Security Groups | Firewall rules for EC2 instances |
| **Cloud Security** | AWS IAM | Permission control for cloud access |
| **Cloud Security** | AWS KMS | Encryption key management |
| **Network Architecture** | NAT Gateway / Bastion Host | Secure EC2 access from private subnets |
| **Infrastructure as Code** | Terraform | Automate cloud infrastructure deployment |
| **Collaboration** | SharePoint Online | Enterprise document storage & governance |
| **Automation** | Power Automate | Automated approval workflows |
| **Scripting** | PowerShell | Windows automation & user provisioning |
| **Scripting** | Bash | Linux system administration |
| **Operations** | ITIL v4 Framework | Change management & service requests |
| **Ticketing** | Jira Service Management | Track infrastructure changes |

---

## Current Status

- Phase 1: In Progress (setting up the virtualization)
- Phase 2-6: Coming soon
## How I'm Documenting This

Every step of this lab is documented in this GitHub repo. Not just the final result – but **how I got there**, what went wrong, how I fixed it, and why I made certain decisions.

For each major phase, I'm creating:
- Step-by-step guides
- Complete scripts (nothing truncated or "insert code here")
- Configuration files
- Troubleshooting notes
- ITIL Change Requests (for operational traceability)

The goal is that someone (or a future me) could follow this documentation and rebuild the entire lab from scratch.

---

## Learning Path

I'm learning this **in order**, so later phases depend on earlier ones being solid:

1. **Phase 1** sets up the isolated network
2. **Phase 2** builds the core infrastructure
3. **Phase 3** adds modern containerization
4. **Phase 4** extends to cloud
5. **Phase 5** automates business processes
6. **Phase 6** wraps it in operational frameworks

## Why This Matters for My Career

Building this lab does three things:

1. **Proves I can learn independently** – I'm not following a course, I'm building something real
2. **Shows depth across multiple areas** – Virtualization, identity, cloud, security, automation, operations
3. **Demonstrates problem-solving** – Every phase will have gotchas; I'm documenting how I solve them

When I interview for roles, I can talk about the **reasoning behind decisions** – not just "I set up Active Directory" but "Here's why I chose Fine-Grained Password Policies for admin accounts" or "Here's how I hardened SSH to disable password authentication."

---

## Getting Started

Each phase has its own folder with detailed documentation. Start with **Phase 1** and work through sequentially.

---

**Last Updated:** June 2025  
**Next Phase:** Phase 1 – Bare-Metal Virtualization & Cloud Licensing

---
