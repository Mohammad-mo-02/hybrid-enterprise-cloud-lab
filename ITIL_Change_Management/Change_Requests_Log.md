# ITIL v4 Change Management Log
## Hybrid Enterprise Infrastructure & Multi-Cloud Automation Lab

**Purpose:** This document maintains a complete audit trail of all change requests (CRs) raised throughout the project build. Upon completion of Phase 6.1 (Jira Service Management / ServiceNow setup), these records will be imported into the live ITSM platform to demonstrate end-to-end change management discipline.

**Owner:** Mohammad
**Project:** Tier-1 Advanced Engineering & Operational Infrastructure Simulation

---

## CR INDEX

| CR ID | Date | Title | Type | Risk | Status |
|-------|------|-------|------|------|--------|
| CR-2026-0619-001 | 2026-06-19 | Phase 2.2 Corrective Action — User OU Distribution & Tiered Admin Structure | Normal (Corrective) | Medium | Implemented & Verified |
| CR-2026-0619-002 | 2026-06-19 | Phase 2.3A — Fine-Grained Password Policy Implementation | Normal | Low | Implemented & Verified |
| CR-2026-0620-003 | 2026-06-20 | Phase 2.3B Prerequisites & Service Desk Runbook | Normal | Low | Implemented & Verified |
| CR-2026-0622-004 | 2026-06-22 | Phase 2.3C Group Policy Object (GPO 1 of 3) | Normal | Low | Implemented & Verified  |
| CR-2026-0622-005 | 2026-06-22 | Phase 2.4 IIS Web Service Deployment & TLS Hardening | Normal | Medium | Implemented & Verified |
---

## CR-2026-0619-001

**Title:** Phase 2.2 Corrective Action — User OU Distribution & Tiered Admin Structure
**Date Raised:** June 19, 2026
**Raised By:** Mohammad (Infrastructure Engineer)
**Change Type:** Normal (Corrective)
**Priority:** High
**Status:** Implemented & Verified

### Change Summary
Remediation of two architectural gaps identified during Phase 2.3A pre-flight review:
1. All 257 AD users were incorrectly located directly in the Administration OU rather than distributed across departmental OUs by their Department attribute.
2. No tiered administrative model (Tier 0/1/2) existed, which is a mandatory prerequisite for Fine-Grained Password Policy (FGPP) application in Phase 2.3A.

### Risk Level
**Overall: MEDIUM**
- Moving 257 live user objects between OUs (bulk Move-ADObject)
- Creating 3 new privileged forest admin accounts
- Creating 3 security groups and assigning 260 members

**Mitigating Factors:**
- Operations performed in isolated host-only lab (no production impact)
- All scripts include error handling and Start-Transcript logging
- Scripts are idempotent (safe to re-run)
- Full pre-flight OU verification before bulk move

### Impact Analysis
- **Systems Affected:** WS2022-DC01 (Domain Controller)
- **Directory Affected:** corp.infralab.local
- **Objects Modified:** 257 users moved, 3 users created, 3 groups created, 260 group memberships added
- **Downtime:** None
- **User Impact:** None (lab environment)
- **Dependency Impact:** Positive — unblocks Phase 2.3A (FGPP), Phase 2.3C (GPO), and Phase 4.1 (Entra Connect sync requires correct OU structure)

### Implementation Steps
1. Executed Fix-UserOUPlacement.ps1 — moved 257 users to departmental OUs (0 errors)
2. Verified 0 users remaining directly in Administration OU
3. Executed Create-TierStructure.ps1 — created Tier 0 OU, 3 forest admin accounts, 3 tier security groups, assigned all members
4. Verified tier group membership: Tier 0 (3), Tier 1 (7), Tier 2 (250)
5. Committed corrective scripts and updated README to GitHub

### Verification / Test Evidence
- PowerShell transcript logs: C:\Logs\Fix-UserOUPlacement-20260619-*.txt and C:\Logs\Create-TierStructure-20260619-*.txt
- Verification query confirmed: 0 users in Administration root
- Tier group counts verified via Get-ADGroupMember
- GitHub commit history reflects corrective scripts + README

### Rollback Plan
1. **User OU Placement:** Re-run a reverse Move-ADObject script to return users to Administration OU (transcript logs provide the original→target mapping for each user).
2. **Tier Structure:**
   - Remove-ADGroupMember to clear group assignments
   - Remove-ADGroup for SG-Tier0/1/2 groups
   - Remove-ADUser for the 3 forest admin accounts
   - Remove-ADOrganizationalUnit for Tier0-Admins OU (disable ProtectedFromAccidentalDeletion first)
3. **AD object recovery:** AD Recycle Bin enabled — deleted objects recoverable for tombstone lifetime if needed.

### Post-Implementation Review
- **Root Cause:** Original 2.2 provisioning script created users without OU distribution logic or tier assignment.
- **Lesson Learned:** Pre-flight dependency review must validate that current-phase deliverables match next-phase prerequisites BEFORE marking a phase complete.
- **Preventive Action:** Master Execution Protocol updated with mandatory phase-to-phase handoff verification.
- **Closure:** Approved — prerequisites for Phase 2.3A now satisfied.

---
## CR-2026-0619-002

**Title:** Phase 2.3A — Fine-Grained Password Policy Implementation
**Date Raised:** June 19, 2026
**Raised By:** Mohammad (Infrastructure Engineer)
**Change Type:** Normal
**Priority:** Medium
**Status:** Implemented & Verified

### Change Summary
Created and applied three tiered Password Settings Objects (PSOs) targeting the tier security groups, enforcing role-appropriate password length, complexity, history, age, and lockout rules.

### Risk Level
**LOW** — Lab environment, additive change (no existing PSOs overwritten), idempotent script with full transcript logging.

### Impact Analysis
- **Systems Affected:** WS2022-DC01
- **Objects Created:** 3 PSOs (PSO-Tier0-Admins, PSO-Tier1-Admins, PSO-Tier2-Users)
- **Targets:** SG-Tier0-Admins, SG-Tier1-Admins, SG-Tier2-Users
- **Downtime:** None
- **Note:** New password rules apply at each user's next password change.

### Implementation Steps
1. Ran Create-FGPP-Policies.ps1 (v2, New-TimeSpan fix)
2. Verified settings via Get-ADFineGrainedPasswordPolicy
3. Verified targets via AppliesTo
4. Verified per-user resolution via Get-ADUserResultantPasswordPolicy

### Verification Evidence
- ForestAdmin-1 resolves to PSO-Tier0-Admins (Precedence 10, MinLength 16, Lockout 3, Duration 1hr)
- Transcript: C:\Logs\Create-FGPP-Policies-20260619-*.txt

### Rollback Plan
Remove-ADFineGrainedPasswordPolicy for each of the three PSOs. Users revert to the default domain password policy. No user objects affected.

### Post-Implementation Review
- **Issue encountered:** First run failed on Tier 0 — 60-minute lockout values were hand-built as "00:60:00", invalid for a TimeSpan (minutes max 59).
- **Resolution:** Switched to New-TimeSpan, which correctly converts 60 min = 1 hr.
- **Lesson:** Build time values with native cmdlets, not string concatenation.
- **Closure:** Approved — prerequisites for Phase 2.3B satisfied.

## CR-2026-0620-003

**Title:** Phase 2.3B Prerequisites & Service Desk Runbook
**Date Raised:** June 20, 2026
**Raised By:** Mohammad (Infrastructure Engineer)
**Change Type:** Normal
**Priority:** Medium
**Status:** Implemented & Verified

### Change Summary
Closed two outstanding gaps from Phase 2.2 and produced the Service Desk Runbook:
1. Created the ten missing department staff security groups (only Finance and IT existed).
2. Created four dedicated service accounts in the ServiceAccounts OU (svc-ansible, svc-backup, svc-sql, svc-monitoring).
3. Executed and documented nine help-desk scenarios against live accounts (account unlock, password reset, group assignment correction, onboarding, offboarding, first-logon flag, logon-failure investigation, manager hierarchy, service account management).

### Risk Level
**LOW** — Lab environment, additive changes, idempotent scripts with transcript logging. Offboarding/onboarding performed on a disposable test account (tom.baker).

### Impact Analysis
- **Systems Affected:** WS2022-DC01
- **Objects Created:** 10 department staff groups, 4 service accounts, 1 test user (tom.baker, subsequently offboarded)
- **Objects Modified:** sarah.johnson (used as test subject across scenarios — unlocked, password reset, group membership, manager set)
- **Downtime:** None
- **Dependency Impact:** Positive — department groups and service accounts required by later phases (Entra Connect sync Phase 4; svc-ansible required by Phase 3.5).

### Implementation Steps
1. Ran Create-DepartmentStaffGroups.ps1 — created 10 groups (idempotent).
2. Ran Create-ServiceAccounts.ps1 — created 4 service accounts with password-never-expires / cannot-change-password flags.
3. Performed nine Service Desk scenarios in ADUC and PowerShell; captured evidence screenshots.

### Verification Evidence
- All 12 department staff groups confirmed via Get-ADGroup.
- 4 service accounts confirmed via Get-ADUser (PasswordNeverExpires = True).
- Runbook README with per-scenario evidence committed to GitHub.

### Rollback Plan
- Remove-ADGroup for the 10 department groups; Remove-ADUser for the 4 service accounts and tom.baker.
- Scenario actions on sarah.johnson are reversible (re-unlock, re-set membership/manager as needed).
- AD Recycle Bin enabled for object recovery.

### Post-Implementation Review
- **Root Cause (gaps):** Original 2.2 infrastructure script created only sample groups and no service accounts.
- **Lesson Learned:** Verify per-department group model and service-account provisioning at 2.2 completion, not at point of dependency.
- **Closure:** Approved — prerequisites satisfied; runbook complete (9 of 10 scenarios; Scenario 9 deferred pending GPOs in 2.3C).

---

## CR-2026-0622-004

**Title:** Phase 2.3C Group Policy Object Implementation (GPO 1 of 3)
**Date Raised:** June 22, 2026
**Raised By:** Mohammad (Infrastructure Engineer)
**Change Type:** Normal
**Priority:** Medium
**Status:** In Progress (GPO 1 complete; GPOs 2 and 3 pending)

### Change Summary
Began Phase 2.3C Group Policy implementation. Created, configured, linked and verified the
first of three GPOs: User-Workstation-Lock-Policy, enforcing a password-protected screen
lock after 15 minutes idle, linked to the Departments OU (inherited by all department
sub-OUs).

### Risk Level
**LOW** — Lab environment, additive change, no modification to built-in default GPOs.

### Impact Analysis
- **Systems Affected:** WS2022-DC01 and (when present) all user objects under the Departments OU.
- **Objects Created:** 1 GPO (User-Workstation-Lock-Policy), 1 GPO link on Departments OU.
- **Settings:** ScreenSaveActive=1, ScreenSaverIsSecure=1, ScreenSaveTimeOut=900 (User Configuration / HKCU).
- **Downtime:** None.
- **Note:** Visible end-user application requires a domain-joined client (Phase 4.2); GPO is created, linked and verified on the DC.

### Implementation Steps
1. New-GPO to create the policy container.
2. Set-GPRegistryValue x3 to configure the screen-lock settings.
3. New-GPLink to link the GPO to the Departments OU.
4. Verified via GPMC (link enabled, status enabled) and PowerShell (Get-GPInheritance, Get-GPRegistryValue).

### Verification Evidence
- GPMC shows GPO linked to Departments OU, Link Enabled: Yes, GPO Status: Enabled.
- PowerShell confirms link and the three stored registry settings.

### Rollback Plan
- Remove-GPLink to unlink from Departments OU.
- Remove-GPO -Name "User-Workstation-Lock-Policy" to delete the GPO entirely.
- Built-in default GPOs untouched.

### Post-Implementation Review
- **Status:** GPO 1 of 3 complete. CR remains open pending GPO 2 (Administrative / removable media) and GPO 3 (Domain-wide security/audit baseline), after which status moves to Implemented & Verified.

---
## CR-2026-0622-005

**Title:** Phase 2.4 IIS Web Service Deployment & TLS Hardening
**Date Raised:** June 22, 2026
**Raised By:** Mohammad (Infrastructure Engineer)
**Change Type:** Normal
**Priority:** Medium
**Status:** Implemented & Verified

### Change Summary
Deployed the IIS web server role on WS2022-DC01, served a custom enterprise corporate
intranet page, and hardened the server's TLS configuration (Schannel) to the Elite Standard
by disabling legacy protocols and enforcing TLS 1.2.

1. Installed the IIS (Web-Server) role with management tools via PowerShell.
2. Replaced the default IIS page with a custom corporate intranet landing page in
   C:\inetpub\wwwroot\index.html.
3. Disabled SSL 2.0, SSL 3.0, TLS 1.0, TLS 1.1 (Server + Client) via Schannel registry keys.
4. Explicitly enabled TLS 1.2 (Server + Client).

### Risk Level
**MEDIUM** — TLS protocol changes affect the entire OS (Schannel), not just IIS, and
required a server reboot. Disabling legacy protocols could disconnect any client that only
supports them.

**Mitigating Factors:**
- Isolated lab; all components support TLS 1.2+, so no legacy dependency exists.
- Changes are registry-based, fully reversible, and were verified after reboot.
- IIS install required no reboot; only the TLS hardening did.

### Impact Analysis
- **Systems Affected:** WS2022-DC01 (IIS role + OS-wide Schannel TLS configuration)
- **Objects Created/Modified:** IIS Web-Server role installed; custom index.html deployed;
  Schannel protocol registry keys set (SSL2/3, TLS1.0/1.1 disabled; TLS1.2 enabled)
- **Downtime:** One planned reboot to apply Schannel changes
- **Service Impact:** Web service now serves a hardened TLS protocol set. HTTPS binding
  (certificate + port 443) deferred to Phase 2.8.
- **Scope Note:** Because Schannel is OS-wide, the hardening also applies to other TLS
  services on the host (e.g. RDP), improving overall security posture.

### Implementation Steps
1. Install-WindowsFeature -Name Web-Server -IncludeManagementTools; verified Installed.
2. Confirmed W3SVC Running/Automatic, Default Web Site Started; HTTP request returned 200.
3. Wrote custom index.html to wwwroot; verified custom page served (title "Infralab
   Corporate Intranet", 200 OK).
4. Set Schannel registry keys to disable weak protocols and enable TLS 1.2 (Server+Client).
5. Rebooted; re-verified protocol state persisted (weak = DISABLED, TLS 1.2 = ENABLED).

### Verification Evidence
- HTTP 200 response and custom page title confirmed via Invoke-WebRequest.
- Post-reboot registry read: SSL 2.0/3.0, TLS 1.0/1.1 = DISABLED; TLS 1.2 = ENABLED.
- Screenshots: rendered corporate page; TLS state before and after hardening.

### Rollback Plan
- **IIS:** Uninstall-WindowsFeature -Name Web-Server (or stop W3SVC) to remove the web service.
- **TLS:** Delete or revert the Schannel protocol registry keys under
  ...\SecurityProviders\SCHANNEL\Protocols (restores OS-default protocol behaviour); reboot.
- All changes reversible; no data loss risk.

### Post-Implementation Review
- **Outcome:** Functional corporate web service deployed and TLS hardened to Elite Standard.
- **Key distinction noted:** Protocol hardening (Schannel) is separate from enabling HTTPS;
  the HTTPS certificate + port 443 binding is scheduled for Phase 2.8, where an end-to-end
  TLS handshake test will confirm the full secure-web-service chain.
- **Closure:** Approved — Phase 2.4 complete; HTTPS binding tracked as a Phase 2.8 dependency.

---
