# Phase 4: Hybrid Multi-Cloud Integration (Azure, Entra ID & AWS)

**Objective:** Architect and implement a production-grade hybrid infrastructure by bridging 
the on-premises Active Directory environment directly to Microsoft Azure and AWS cloud 
ecosystems — demonstrating unified identity governance, Zero Trust endpoint control, 
declarative cloud infrastructure provisioning, and automated backup lifecycle management 
across a genuine multi-cloud technical profile.

## Sub-phases

| Sub-phase | Description | Status |
|---|---|---|
| [4.1 – Entra Connect Directory Bridging](./Phase_4.1_Entra_Connect_Directory_Bridging/README.md) | Sync on-prem AD to Microsoft Entra ID via Password Hash Sync, with Zero Trust Conditional Access | In progress |
| 4.2 – Windows 11 Hybrid Join | Domain-join a Windows 11 Enterprise VM, verify hybrid identity resolution | Not started |
| 4.3 – Intune Compliance | Enrol workstation into Intune, enforce BitLocker + USB restriction policies | Not started |
| 4.4 – AVD Host Pool | Provision Azure Virtual Desktop mapped to hybrid-synced identities | Not started |
| 4.5 – AWS EC2 + Terraform VPC | Multi-AZ VPC, private-subnet EC2, NAT Gateway, Bastion Host — declared as HCL | Not started |
| 4.6 – Security Groups, IAM, NACLs | Least-privilege network and identity security layered on 4.5 | Not started |
| 4.7 – S3 Backup Lifecycle | Encrypted, versioned S3 bucket with tiered lifecycle rules — declared as Terraform | Not started |
