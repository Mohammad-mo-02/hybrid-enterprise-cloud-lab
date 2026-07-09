# Phase 4.1 – Entra Connect Directory Bridging

## Objective
Establish hybrid identity by synchronising the on-premises Active Directory domain 
(corp.infralab.local) into Microsoft Entra ID using Microsoft Entra Connect Sync, so 
that on-prem and cloud identities share a single authoritative source — creating the 
foundation for Zero Trust Conditional Access, Intune device compliance, and Azure 
Virtual Desktop later in this phase.

## Architecture & design decisions

### Sync scope: Administration OU excluded
The Entra Connect sync account effectively holds Replicating Directory Changes rights 
over anything it's scoped to sync — functionally equivalent to a Domain Controller. To 
avoid creating a blast-radius bridge between the on-prem privileged tier and the cloud 
plane, the Administration OU (Tier 0 admin accounts) is explicitly excluded from the 
sync scope via OU filtering. Only the Departmental OUs (247 standard users) are synced, 
so a compromise of either environment cannot automatically cascade into the other.

### Sync method: Password Hash Sync (PHS)
Chosen over Pass-Through Authentication and AD FS Federation. PHS syncs a SHA-256-hashed 
copy of the password hash (never a reversible credential) and allows authentication to 
complete entirely in the cloud, removing dependency on constant on-prem network 
availability. It is Microsoft's current default recommendation and pairs cleanly with 
the Conditional Access / MFA work planned later in this phase.

### Server placement: DC01
Best practice is a dedicated member server for Entra Connect, since the server itself 
becomes a Tier 0 / Control Plane asset the moment it's installed. Given the lab currently 
has only two VMs, Entra Connect is installed directly on DC01 — a deliberate, documented 
trade-off for lab-scale pace rather than an oversight.

### UPN / domain strategy
corp.infralab.local cannot be verified as a custom domain in Entra ID (.local is not a 
routable public TLD). Synced users therefore receive a cloud UPN under the tenant's 
default *.onmicrosoft.com domain rather than matching their on-prem UPN suffix. This 
does not affect functionality — MFA, Conditional Access, and sync all work identically — 
it only affects how the UPN displays.

## Part 1 — Network preparation on DC01

DC01 originally had only a single, host-only network adapter (10.0.0.10), fully isolated 
from the internet by design. Entra Connect requires outbound HTTPS connectivity to 
Microsoft's cloud endpoints on an ongoing basis, so a second, NAT-attached adapter was 
added — mirroring the existing dual-NIC pattern already used on LNX-SRV-01.

Steps performed:
- Added a second virtual network adapter to DC01 in VMware Workstation, attached to NAT (VMnet8).
- Confirmed the new adapter (Ethernet1) received a DHCP lease from the NAT network: 192.168.181.130.
- Confirmed the original internal adapter (Ethernet0) remained untouched: 10.0.0.10, gateway 10.0.0.1.
- Disabled DNS registration on the new NAT adapter, to prevent it polluting the internal AD DNS zone.
- Added public DNS forwarders (8.8.8.8, 1.1.1.1) to the DNS Server role for internet name resolution.
- Verified outbound connectivity and DNS resolution to Microsoft endpoints.

Documentation discrepancy caught and resolved: earlier notes referenced DC01's static IP 
as 10.0.0.1. On-screen verification confirmed the correct address is 10.0.0.10, with 
10.0.0.1 actually being the gateway. DNS client settings were confirmed already pointing 
correctly to 127.0.0.1 (loopback) — DC01 resolves its own domain via itself, as expected 
for a DC also running the DNS Server role.

## Part 2 — Microsoft Entra tenant setup

A Microsoft Entra ID Free tenant already existed automatically, tied to the personal 
Microsoft account used to access the Azure portal ("Default Directory", domain 
arsalansomersetgmail.onmicrosoft.com) — no paid subscription or trial required. This 
tenant does not expire on a timer.

Steps performed:
- Confirmed the personal Microsoft account held the Global Administrator role by default.
- Created a dedicated, tenant-native administrator account (admin@arsalansomersetgmail.onmicrosoft.com) 
  and assigned it Global Administrator, rather than continuing to use the personal account 
  for privileged operations — following the principle that day-to-day personal accounts 
  should never double as top-tier admin accounts.
- Verified MFA (Microsoft Authenticator, push notification) was registered and functional 
  on the new admin account.
- Confirmed successful authentication via the Entra sign-in activity log.

## Part 3 — Locating and downloading Microsoft Entra Connect Sync

Microsoft Entra Connect is now offered in two forms: Cloud Sync (lightweight, agent-based) 
and Connect Sync (the traditional full sync engine). Connect Sync was selected, since it 
supports the fine-grained OU scoping filter required to exclude the Administration OU, 
and matches the project's original specification.

Navigated: Entra admin centre → Microsoft Entra Connect → Connect Sync → Manage tab → 
downloaded the Connect Sync Agent installer.

## Status
Installer downloaded to host machine. Not yet transferred to DC01 or installed. 
Next: transfer installer into DC01, run Custom installation (PHS, OU filtering applied 
at install time), verify first sync cycle.

## Screenshots

Uploaded in the order the work was carried out:

1. Network Connections window showing both adapters (Ethernet0, Ethernet1) after adding the second NIC.
2. Ethernet1 status details, confirming the NAT adapter received 192.168.181.130.
3. Ethernet0 TCP/IPv4 properties, confirming the internal adapter's static IP (10.0.0.10) and DNS (127.0.0.1).
4. Entra ID "Default Directory" tenant overview page.
5. Global Administrator role assignments, confirming the personal account held Global Admin by default.
6. New dedicated admin account creation screen.
7. Security info page showing Password and Microsoft Authenticator registered.
8. Sign-in activity log confirming successful authentication with the new account.
9. Entra admin centre home page, showing Microsoft Entra Connect as "Disabled" before install.
10. Microsoft Entra Connect "Get started" page comparing Cloud Sync and Connect Sync.
11. Connect Sync page showing "Not installed" prior to download.
12. The download page showing the Connect Sync Agent installer button.
13. Users list showing both the personal account and the new dedicated admin account side by side.
