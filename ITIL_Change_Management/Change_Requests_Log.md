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
