# 2.3: Identity Policies & Help Desk Operations

## What This Contains
- FGPP (Fine-Grained Password Policies) scripts
- Group Policy Objects (GPO) scripts
- Help desk runbook with 10 scenarios

# Phase 2.3A: Fine-Grained Password Policies (FGPP)

## Overview
Three tiered Password Settings Objects (PSOs) enforce role-appropriate password
and lockout rules, applied to tier-based security groups (not OUs — AD does not
permit PSOs to target OUs; they apply to users or global security groups only).

## Policy Matrix

| Setting | PSO-Tier0-Admins | PSO-Tier1-Admins | PSO-Tier2-Users |
|---|---|---|---|
| Precedence | 10 | 20 | 30 |
| Applied to group | SG-Tier0-Admins | SG-Tier1-Admins | SG-Tier2-Users |
| Min password length | 16 | 14 | 12 |
| Complexity | Enabled | Enabled | Enabled |
| Password history | 12 | 8 | 5 |
| Max password age | 30 days | 45 days | 60 days |
| Min password age | 1 day | 1 day | 1 day |
| Lockout threshold | 3 | 5 | 5 |
| Lockout duration | 60 min | 30 min | 30 min |
| Lockout observation window | 60 min | 30 min | 30 min |

## Precedence Rules
A PSO carries a precedence value. If a user is subject to more than one PSO
(e.g. via membership in two targeted groups), AD does **not** merge the policies
or auto-select the strictest. It applies the single PSO with the **lowest
precedence number** and ignores the rest. Tier 0 is therefore set to 10 so the
most privileged accounts always receive the strictest policy. The spec intent
("most restrictive wins") is realised through deliberate precedence ordering.

## Verification
Per-user resultant policy confirmed with:
`Get-ADUserResultantPasswordPolicy -Identity <user>`
ForestAdmin-1 resolves to PSO-Tier0-Admins (Precedence 10, MinLength 16,
Lockout 3, Duration 1hr), confirming correct end-to-end application.

## Idempotency
The creation script is safe to re-run: existing PSOs are updated via
Set-ADFineGrainedPasswordPolicy rather than recreated, and group bindings are
checked before being added.
# Phase 2.3B: Service Desk Simulator — Help Desk Runbook

**Purpose:** A practical first-line support runbook documenting the resolution of ten
common Active Directory help desk scenarios. Each scenario is resolved two ways — via
**Active Directory Users and Computers (ADUC)** for hands-on GUI support, and via
**PowerShell** for scalable/automated resolution — with diagnosis steps, expected
outcomes, common mistakes, and escalation paths. Suitable for new-hire help desk
training.

**Environment:** `corp.infralab.local` | Domain Controller: `WS2022-DC01`
**Author:** Mohammad

---

## Scenario 1: Unlocking a Locked Account

**Ticket Example:** *"I can't log in — it says my account is locked. I didn't change anything!"*

### Background
Account lockout is a security control, not a fault. When a user exceeds the failed
logon threshold defined in the applicable Fine-Grained Password Policy (Tier 2 = 5
attempts; Tier 0 = 3), Active Directory temporarily freezes the account to block
further password guessing. The account is **not** disabled and the password is **not**
changed — it is simply frozen until an administrator unlocks it, or the lockout
duration (Tier 2 = 30 minutes) expires.

**Key distinction:** *Unlocking* clears the freeze so the user can retry their
**existing** password. It is **not** the same as a password reset (Scenario 2). If a
user is locked out but still knows their password (e.g. Caps Lock was on), unlock only
— do not reset.

### Diagnosis
Always confirm the account is genuinely locked before taking action:

```powershell
Get-ADUser -Identity "sarah.johnson" -Properties LockedOut, badPwdCount, AccountLockoutTime |
    Select-Object Name, LockedOut, badPwdCount, AccountLockoutTime | Format-List
```

A locked account shows `LockedOut: True`, a `badPwdCount` at or above the policy
threshold, and a populated `AccountLockoutTime`.

**Evidence — locked state (badPwdCount 5, LockedOut True):**

![Locked account state](screenshots/Before_phase_scenario_1.png)

> *Test condition note:* For demonstration, the lockout was deliberately manufactured
> by attempting authentication with a wrong password six times (Tier 2 policy locks at
> five). This also serves as live proof that the Phase 2.3A FGPP lockout policy is
> actively enforced.

### Resolution — Method A: ADUC (GUI)
1. Open **Active Directory Users and Computers**.
2. Locate the user — right-click the domain root → **Find**, type `sarah.johnson`,
   then **Find Now** (faster than browsing OU by OU).
3. Double-click the user → select the **Account** tab.
4. Tick **"Unlock account. This account is currently locked out..."**
   (This line only appears when the account is actually locked.)
5. Click **Apply**, then **OK**.

**Evidence — ADUC Find dialog and Account tab with Unlock ticked:**

![ADUC unlock](screenshots/AD_Account_Unlock_Scenario_1.png)

### Resolution — Method B: PowerShell (CLI)
Single account:

```powershell
Unlock-ADAccount -Identity "sarah.johnson"
```

Bulk reference — unlock **every** locked account in the domain at once (useful after a
policy misconfiguration locks many users; not required for a single ticket):

```powershell
Search-ADAccount -LockedOut | Unlock-ADAccount
```

### Expected Outcome
`LockedOut` returns **False**, `badPwdCount` resets to **0**, and `AccountLockoutTime`
clears. The user can immediately log in again using their existing password.

**Evidence — verified unlocked state (LockedOut False, badPwdCount 0, timestamp cleared):**

![Verified unlocked](screenshots/Scenario_1_powershell_check_.png)

### Common Mistakes
- **Resetting the password when only an unlock was needed** — forces an unnecessary
  credential change and confuses the user.
- **Not confirming the root cause** — if an account re-locks within minutes of
  unlocking, something is *actively* submitting bad logons (a stale cached password on
  a phone, a mapped drive, a saved Wi-Fi/VPN credential, or a genuine attack).
  Unlocking alone will not fix a recurring lockout.
- **Skipping verification** — always re-query `LockedOut` after the action to confirm
  the fix landed.

### Escalation Path
- **Account re-locks repeatedly after unlocking** → escalate to **Tier 2 / Security**:
  investigate the source of failed logons via Event Viewer (Security log — Event ID
  **4740** for lockouts, **4625** for failed logons). See Scenario 7.
- **Many users locked out simultaneously** → possible policy misconfiguration or
  coordinated attack → escalate to the **Security team** immediately.

### Evidence Captured
| Evidence | File |
|---|---|
| Locked state (before) | `screenshots/Before_phase_scenario_1.png` |
| ADUC unlock (Account tab) | `screenshots/AD_Account_Unlock_Scenario_1.png` |
| Verified unlocked (after) | `screenshots/Scenario_1_powershell_check_.png` |

---
