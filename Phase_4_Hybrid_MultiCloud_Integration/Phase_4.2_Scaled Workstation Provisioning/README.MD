Phase 4.2 — Scaled Workstation Provisioning & Hybrid Identity Enrolment

Objective: Deploy a Windows 11 Enterprise workstation into the isolated lab, join it to the on-premises Active Directory domain, and prove that the machine resolves against both on-premises AD and Microsoft Entra ID simultaneously — a genuine Microsoft Entra hybrid join, not a plain domain join.

Outcome: WIN11-CLIENT01 is verifiably hybrid-joined — confirmed on the device (dsregcmd /status) and independently in the Entra admin centre. This delivers the device prerequisite that Phase 4.3 (Intune enrolment and compliance) depends on.


1. Concept — why "hybrid join", not just "domain join"

A Windows device can hold one of three join states:


Domain-joined — trusts on-premises AD only. The cloud has never heard of it.
Entra-joined — cloud-native, trusts Entra ID only, no on-prem AD.
Hybrid Entra join — joined to on-prem AD and registered as a device object in Entra ID at the same time. One machine, known to both planes.


Phase 4.2's real deliverable is the third state. The naïve reading ("make a VM, join the domain, done") passes a green tick but silently breaks Phase 4.3: Intune manages devices that exist in Entra ID. A domain-join-only machine never appears in Entra, so there would be nothing for 4.3 to enrol. Hybrid join is therefore the load-bearing requirement, not a nice-to-have.

Recurring principle — explicit over implicit / discovery via the directory: the device does not guess or hardcode its tenant. It looks it up in a well-known object in Active Directory (the Service Connection Point, below).


2. Prerequisite caught before build — the Service Connection Point (SCP)

Hybrid join depends on a Service Connection Point (SCP): a small object written into the forest's Configuration partition that acts as a signpost telling every domain-joined device which Entra tenant to register with. It carries two values — azureADid (tenant GUID) and azureADName (verified domain).

Before building anything, the SCP was checked and found absent — Phase 4.1 configured user synchronisation (Password Hash Sync) but never ran the Entra Connect device options step that writes the SCP. This gap would have caused the workstation to domain-join successfully yet never register into Entra (a silent failure that would only surface in 4.3).

Remediation: ran Microsoft Entra Connect → Configure device options → Configure Microsoft Entra hybrid join on DC01, selecting forest corp.infralab.local, authentication service Azure Active Directory (managed domain — no ADFS), with Enterprise Admin credentials.

Verification (in code, not the wizard's word):

powershell$scp = New-Object System.DirectoryServices.DirectoryEntry
$scp.Path = "LDAP://CN=62a0ff2e-97b9-4513-943f-0d221bd30080,CN=Device Registration Configuration,CN=Services,CN=Configuration,DC=corp,DC=infralab,DC=local"
$scp.Keywords

Returned:

azureADName:arsalansomersetgmail.onmicrosoft.com
azureADId:df8403b0-4503-4df0-9f25-40f6c0d0a932

Show Image
Evidence 1 — SCP present in the forest Configuration partition, pointing domain-joined devices at the correct tenant.


3. Workstation build

Built in VMware Workstation Pro, stored at C:\Lab_Infrastructure\WIN11-CLIENT01 (never OneDrive — cloud sync previously corrupted lab VMs).

SettingValueReasonOSWindows 11 Enterprise (Evaluation), build 26200.6584Enterprise SKU allows offline/local-account OOBE and domain joinFirmwareUEFI + Secure BootWindows 11 hard requirementTPMVirtual TPM 2.0 (VM encrypted, TPM-only files)Hardware-bound device key; required by Win11 and used by Entra device authCPU / RAM / Disk2 vCPU / 4 GB / 64 GBAdequate managed clientNIC 1Host-only (VMnet1) — static 10.0.0.30/24, DNS 10.0.0.10, no gatewayTalks to DC01 on the isolated lab networkNIC 2NAT (VMnet8) — DHCPControlled internet egress to Entra endpoints for device registration

Design note — dual-homed networking. The workstation must reach two different places for two different jobs: DC01 (domain join, on the isolated host-only network) and Entra's cloud endpoints (enterpriseregistration.windows.net, login.microsoftonline.com) for the hybrid registration. Hence two adapters.

Principle — isolation is from the home LAN, not from the internet. The lab never touches the personal network (host-only), but the NAT switch is a deliberate, controlled egress boundary — outbound to Microsoft's cloud, no inbound exposure. A truly air-gapped workstation could not be hybrid-joined at all.

Principle — one default gateway per host. The host-only NIC deliberately has no default gateway; it only serves the local 10.0.0.0/24. The NAT NIC owns the single default route to the internet. Two competing default gateways would blackhole the internet the registration depends on.

Principle — DNS = location, not identity. The host-only NIC's DNS points at DC01 (10.0.0.10) so the client can resolve the domain's SRV records and find the domain controller. Any other DNS server would fail domain join with "domain not found" even though the DC is one hop away.


4. Domain join & rename

Joined to corp.infralab.local (NetBIOS CORP). Windows had auto-named the machine DESKTOP-JTKH3DR; it was renamed to WIN11-CLIENT01 before the cloud registration finalised, so the Entra device object carries a clean, meaningful name rather than a random string.

powershellRename-Computer -NewName WIN11-CLIENT01 -Restart


5. Hybrid join verification (the payoff)

On the device — dsregcmd /status:

AzureAdJoined    : YES
DomainJoined     : YES
DomainName       : CORP
Device Name      : WIN11-CLIENT01.corp.infralab.local
DeviceId         : 671bc650-df07-464c-81de-c3779077cdf5
TpmProtected     : YES
DeviceAuthStatus : SUCCESS
TenantId         : df8403b0-4503-4df0-9f25-40f6c0d0a932


AzureAdJoined: YES + DomainJoined: YES — the literal definition of hybrid join. Both directories trust the machine.
DeviceAuthStatus: SUCCESS — the device authenticated to Entra with its own certificate; it can now be evaluated by Conditional Access and managed by Intune.
TenantId matches the azureADId written into the SCP in §2 — proving the discovery chain end-to-end (SCP → discovery → registration).
TpmProtected: YES — the device's private key is bound to the TPM (hardware-backed identity; cannot be exfiltrated).


Show Image
Evidence 2 — on-device confirmation of hybrid join.

In the cloud — Entra admin centre → Devices → All devices:

WIN11-CLIENT01 shows Join type: Microsoft Entra hybrid joined, Enabled, registered on the build date.

Show Image
Evidence 3 — cloud-side confirmation; both directories independently agree the device exists and is trusted.


6. Design rationale — the four questions (device registration path)


What is it / why does it exist? A mechanism that lets a domain-joined machine also announce itself to Entra ID so cloud services (Intune, Conditional Access) can reason about it — extending on-prem trust into the cloud without abandoning AD.
What can reach it / what can it reach? The device reads the SCP in AD to learn its tenant, then talks outbound to Entra. No inbound internet exposure is required.
Security boundary / blast radius? The device is now a first-class object evaluated by Conditional Access (e.g. CA02 — block non-compliant devices). If the SCP were misconfigured, the device could register to the wrong tenant or silently fail compliance.
What happens when it fails? Domain join still works (users can log in), but AzureAdJoined stays NO, the device never surfaces in Entra, and Phase 4.3 stalls. The failure is silent — the machine looks fine. Hence verification in code, never trusting a green tick.



7. Status & next phase

Verified complete:


SCP armed and confirmed in AD.
Windows 11 Enterprise workstation built, hardened (UEFI + Secure Boot + TPM), dual-homed, off cloud-synced storage.
Domain-joined to corp.infralab.local; renamed to WIN11-CLIENT01.
Hybrid Entra join confirmed on-device and in the Entra portal.


Pending confirmation (non-blocking): user-side Primary Refresh Token (PRT) — logging in as a synced pilot user (Abigail James) and confirming AzureAdPrt : YES in dsregcmd /status. This proves a single on-prem credential mints a cloud token. It will be confirmed as a short follow-up and is exercised naturally in Phase 4.3 when Intune/compliance evaluates a signed-in user.

Forward dependency satisfied: Phase 4.3 (Intune auto-enrolment + compliance policies) requires the device to exist in Entra ID. That requirement is now met.
