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

![Locked account state](Before%20phase%20scenario%201.png)

> *Test condition note:* For demonstration, the lockout was deliberately manufactured
> by attempting authentication with a wrong password six times (Tier 2 policy locks at
> five). This also serves as live proof that the Phase 2.3A FGPP lockout policy is
> actively enforced. The reproduction script is included as
> `Scenario 1 AD lockout Script.txt`.

### Resolution — Method A: ADUC (GUI)
1. Open **Active Directory Users and Computers**.
2. Locate the user — right-click the domain root → **Find**, type `sarah.johnson`,
   then **Find Now** (faster than browsing OU by OU).
3. Double-click the user → select the **Account** tab.
4. Tick **"Unlock account. This account is currently locked out..."**
   (This line only appears when the account is actually locked.)
5. Click **Apply**, then **OK**.

**Evidence — ADUC Find dialog and Account tab with Unlock ticked:**

![ADUC unlock](AD%20Account%20Unlock%20Scenario%201.png)

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

![Verified unlocked](Scenario%201%20powershell%20check%20.png)

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
| Locked state (before) | `Before phase scenario 1.png` |
| ADUC unlock (Account tab) | `AD Account Unlock Scenario 1.png` |
| Verified unlocked (after) | `Scenario 1 powershell check .png` |
| Reproduction script | `Scenario 1 AD lockout Script.txt` |

---
## Scenario 2: Resetting a User's Password

**Ticket Example:** *"I've forgotten my password and I can't get in."*

### Background
The most common help desk request. Unlike a lockout (Scenario 1), the user genuinely
cannot authenticate because they do not know their credential. The fix is to set a new
**temporary** password and force the user to change it at next logon.

**Critical security principle — force change at next logon:** When an administrator
resets a password, the admin now knows that password. A user's credential should be
known only to them. Therefore every human-account reset must set
**"User must change password at next logon"**, so the user logs in once with the temp
password and AD immediately forces them to set a new private one. Skipping this leaves
the admin in possession of a working user credential — a security failure.

### Diagnosis
Confirm the account and check whether it is already in a forced-change state:

```powershell
Get-ADUser -Identity "sarah.johnson" -Properties PasswordLastSet, PasswordExpired, pwdLastSet |
    Select-Object Name, PasswordLastSet, PasswordExpired, pwdLastSet | Format-List
```

A `pwdLastSet` of `0` (shown as a blank `PasswordLastSet`) with `PasswordExpired: True`
indicates the account is flagged to change its password at next logon — the normal
state for a newly provisioned or freshly reset account.

### Resolution — Method A: ADUC (GUI)
1. Open **Active Directory Users and Computers**.
2. Locate the user — right-click domain root → **Find** → `sarah.johnson` → **Find Now**.
3. **Right-click the user** → **Reset Password** (a dedicated dialog, not Properties).
4. Enter a temporary password meeting the user's policy (Tier 2: min 12 chars,
   complexity), e.g. `TempPass2026!`.
5. Ensure **"User must change password at next logon"** is ticked.
6. (Optional) Tick **"Unlock the user's account"** to clear any existing lock.
7. Click **OK** — confirm the success dialog.

![ADUC password reset dialog](Scenario%202%20AD%20Password%20Reset.png)

### Resolution — Method B: PowerShell (CLI)
```powershell
# Set a new temporary password
$newPwd = ConvertTo-SecureString "TempPass2026!" -AsPlainText -Force
Set-ADAccountPassword -Identity "sarah.johnson" -Reset -NewPassword $newPwd

# Force change at next logon (the critical security control)
Set-ADUser -Identity "sarah.johnson" -ChangePasswordAtLogon $true
```

### Expected Outcome
The temporary password is accepted, and the account is flagged to force a change at
next logon (`pwdLastSet: 0`, `PasswordExpired: True`). The user logs in once with the
temp password and is immediately required to set a new private password.

**Verification used here:** the new password was proven functional by temporarily
clearing the change-at-next-logon flag, authenticating with the temp password
(SUCCESS), then restoring the flag — confirming both that the reset worked and that the
security control is back in place.

![Password reset verified](Scenario%202%20powershell%20check.png)

### Common Mistakes
- **"The server has rejected the client credentials" after a reset is NOT necessarily a
  failure.** When *change-at-next-logon* is set, a normal authentication bind is
  blocked until the password is changed — producing a "rejected credentials" message
  even though the password is correct. Do not assume the reset failed; verify properly
  (temporarily clear the flag, test, then restore it).
- **Forgetting to tick "must change at next logon"** — leaves the admin's temporary
  password as the user's live credential. A security failure.
- **Choosing a temp password that fails the policy** — Tier 2 requires 12+ characters
  with complexity; a weak temp password is rejected.
- **Confusing reset with unlock** — if the user knows their password and is only locked
  out, unlock (Scenario 1); do not reset.

### Escalation Path
- User cannot change the password at next logon despite the flag → check the applicable
  FGPP and any "User cannot change password" setting on the account.
- Repeated reset requests from the same user in a short period → possible account
  compromise or training issue → flag to **Tier 2 / Security**.

### Evidence Captured
| Evidence | File |
|---|---|
| ADUC reset dialog (fix) | `Scenario 2 AD Password Reset.png` |
| Password verified working (proof) | `Scenario 2 powershell check.png` |

---
## Scenario 3: Correcting Group Assignments

**Ticket Example:** *"Sarah Johnson has transferred from Sales to Finance — please update her access. She still can't open Finance files and can still see Sales material she shouldn't."*

### Background
Group membership is the engine of **least privilege** in Active Directory: access is
granted to *groups* (roles), and users inherit it via membership. When a user changes
role, the correction has **two halves** — *add* the new access and *remove* the old.
Forgetting the removal causes **privilege creep**: access accumulates across roles until
a single compromised account can reach everything (a large **blast radius**). Removing
old access is as important as granting new access.

### Diagnosis
List current membership before acting:
```powershell
Get-ADPrincipalGroupMembership -Identity "sarah.johnson" | Select-Object Name | Sort-Object Name
```
A user transferring departments will still show their **old** department group — that is
the access to remove.

![Before — Sales membership](Scenario%203%20before%20Sales%20membership.png)

### Resolution — Method A: ADUC (GUI)
1. ADUC → right-click domain root → **Find** → `sarah.johnson` → **Find Now**.
2. Double-click the user → **Member Of** tab.
3. Select the old group (`SG-Sales-Staff`) → **Remove** → confirm.
4. **Add...** → type `SG-Finance-Staff` → **Check Names** → **OK**.
5. **Apply** → **OK**.

![After — Member Of corrected](Scenario%203%20AD%20Member%20Of%20corrected.png)

### Resolution — Method B: PowerShell (CLI)
```powershell
Remove-ADGroupMember -Identity "SG-Sales-Staff" -Members "sarah.johnson" -Confirm:$false
Add-ADGroupMember    -Identity "SG-Finance-Staff" -Members "sarah.johnson"
```

### Expected Outcome
Membership shows `SG-Finance-Staff` present and `SG-Sales-Staff` **absent**. Access
added and old access removed — a complete correction.

![After — Finance corrected](Scenario%203%20after%20Finance%20corrected.png)

### Common Mistakes
- **Adding new access but not removing the old** — the single most common error;
  causes privilege creep and widens blast radius.
- **Group changes don't apply until the user logs off/on** — a new Kerberos token is
  issued at logon; an existing session keeps the old membership until then.
- **Editing individual permissions instead of group membership** — bypasses the
  role-based model and creates unmanageable one-off access.

### Escalation Path
- User still lacks access after re-logon → check whether the *resource* (file share) is
  actually permissioned to `SG-Finance-Staff`, and check for nested group / deny-rule
  conflicts → escalate to **Tier 2**.

### Evidence Captured
| Evidence | File |
|---|---|
| Before (Sales) | `Scenario 3 before Sales membership.png` |
| ADUC Member Of corrected | `Scenario 3 AD Member Of corrected.png` |
| After (Finance, Sales removed) | `Scenario 3 after Finance corrected.png` |

---
## Scenario 4: New Employee Onboarding

**Ticket Example:** *"New starter Tom Baker joins Finance on Monday — please create his account and access."*

### Background
Onboarding applies **least privilege from day one**: the account is created, placed in
the correct departmental OU, granted only its role-based groups (department + tier), and
forced to set a private password at first logon. A complete onboard = identity + correct
location + correct group access + forced password change — not just "create a user."

### Resolution — PowerShell (CLI)
```powershell
$pwd = ConvertTo-SecureString "Welcome2026!Start" -AsPlainText -Force
New-ADUser -Name "Tom Baker" -GivenName "Tom" -Surname "Baker" `
    -SamAccountName "tom.baker" -UserPrincipalName "tom.baker@corp.infralab.local" `
    -DisplayName "Tom Baker" -Title "Finance Analyst" -Department "Finance" `
    -Path "OU=Finance,OU=Departments,OU=Administration,DC=corp,DC=infralab,DC=local" `
    -AccountPassword $pwd -Enabled $true -ChangePasswordAtLogon $true
Add-ADGroupMember -Identity "SG-Finance-Staff" -Members "tom.baker"
Add-ADGroupMember -Identity "SG-Tier2-Users"   -Members "tom.baker"
```

### Resolution — ADUC (GUI) equivalent
Right-click target OU → **New → User** → complete wizard, tick **"User must change
password at next logon"** → then **Member Of** tab → **Add** department and tier groups.

### Expected Outcome
Account exists in the Finance OU, Enabled, Department populated, member of
`SG-Finance-Staff`, `SG-Tier2-Users` and `Domain Users`, flagged to change password at
first logon.

![New starter onboarded](Scenario%204%20new%20starter%20onboarded.png)

### Common Mistakes
- **Creating the account but forgetting group membership** — user exists but can't
  access anything ("I'm set up but nothing works").
- **Skipping change-at-next-logon** — admin's temp password becomes the live credential.
- **Wrong OU placement** — breaks any OU-targeted GPO and department-based logic.
- **Over-granting "to be safe"** — violates least privilege; grant only role groups.

### Escalation Path
- Starter needs access beyond standard role (e.g. cross-department systems) → route to
  **resource owner / manager approval**, do not grant ad hoc.

### Evidence Captured
| Evidence | File |
|---|---|
| Onboarded user + groups | `Scenario 4 new starter onboarded.png` |

---
## Scenario 5: Employee Termination (Offboarding)

**Ticket Example:** *"Tom Baker has left the company effective today — please disable his access immediately."*

### Background
Offboarding follows **disable, don't delete**. The account is disabled (instant access
cut-off), its password reset (invalidates any cached or active credential), group
memberships stripped, and the account tagged as a leaver for audit. It is retained — not
deleted — because it may own files, a mailbox, or be referenced by other systems, and
because audit/retention policy usually requires keeping it for a defined period.
Deleting immediately destroys ownership links and audit history. A live account for a
departed employee is a significant **blast radius** risk.

### Resolution — PowerShell (CLI)
```powershell
# Disable, reset password, tag as leaver, remove department access
Disable-ADAccount -Identity "tom.baker"

$randomPwd = ConvertTo-SecureString ("Offb!" + [guid]::NewGuid().ToString().Substring(0,12)) -AsPlainText -Force
Set-ADAccountPassword -Identity "tom.baker" -Reset -NewPassword $randomPwd

Set-ADUser -Identity "tom.baker" -Description "LEAVER - disabled <date> - pending deletion after retention period"
Remove-ADGroupMember -Identity "SG-Finance-Staff" -Members "tom.baker" -Confirm:$false
```

### Resolution — ADUC (GUI) equivalent
Right-click user → **Disable Account**. Right-click → **Reset Password** (set a random
value). **Member Of** tab → remove department/tier groups. **Properties → Description** →
record leaver date.

### Expected Outcome
`Enabled: False`, leaver note recorded in Description, department group removed. Account
retained (disabled) pending the retention period, then deleted per policy. `Domain Users`
remains (cannot be removed; harmless while account is disabled).

![Offboarding disabled](Scenario%205%20offboarding%20disabled.png)

### Common Mistakes
- **Deleting instead of disabling** — destroys file ownership, mailbox access and audit
  trail; irreversible.
- **Disabling but not resetting the password** — cached credentials or active sessions
  (e.g. mobile mail) may persist; resetting forces re-authentication that now fails.
- **Leaving group memberships intact** — if the account is ever re-enabled in error, it
  regains full access instantly.
- **No audit note** — nobody can tell later why the account is disabled or when it can be
  purged.

### Escalation Path
- Account owns shared resources / mailbox needing handover → coordinate with **manager
  and resource owners** before retention period expires and the account is deleted.
- Suspected malicious leaver → escalate to **Security** for immediate session
  revocation and access review.

### Evidence Captured
| Evidence | File |
|---|---|
| Disabled + leaver-tagged + group removed | `Scenario 5 offboarding disabled.png` |

---
## Scenario 6: Managing First-Logon Password Changes

**Ticket Example:** *"The new starter can't log in — it keeps demanding a password change,"* or *"Please force this user to reset their password at next login."*

### Background
The **"user must change password at next logon"** flag ensures only the user knows their
final password after any admin-set or initial password. Technically it is the
`pwdLastSet` attribute: a value of **0** means the flag is **ON** (change required); a
**timestamp** means the user has set their own password (flag OFF). When ON, the account
also reports `PasswordExpired: True` — by design, to force the change. Understanding that
`pwdLastSet = 0` is the underlying mechanism is the core knowledge for this scenario.

### Diagnosis
Read the flag (translating the raw attribute into a readable True/False):
```powershell
Get-ADUser -Identity "sarah.johnson" -Properties pwdLastSet, PasswordExpired |
    Select-Object Name,
        @{N='MustChangeAtLogon';E={$_.pwdLastSet -eq 0}},
        PasswordExpired | Format-List
```

### Resolution — PowerShell (CLI)
```powershell
# Force change at next logon ON:
Set-ADUser -Identity "sarah.johnson" -ChangePasswordAtLogon $true

# To clear it (user keeps current password) — used when the prompt is unwanted:
Set-ADUser -Identity "sarah.johnson" -ChangePasswordAtLogon $false
```

### Resolution — ADUC (GUI)
1. ADUC → right-click domain root → **Find** → `sarah.johnson` → **Find Now**.
2. Double-click user → **Account** tab.
3. In **Account options**, tick **"User must change password at next logon."**
4. **Apply** → **OK**.

![ADUC first-logon flag](Scenario%206%20ADUC%20first%20logon%20flag.png)

### Expected Outcome
With the flag ON: `MustChangeAtLogon = True`, `PasswordExpired = True`; the user is
prompted to set a new password at next login. With it OFF: the user retains their current
password and is not prompted.

![First-logon flag state](Scenario%206%20first%20logon%20flag.png)

### Common Mistakes
- **"Must change at next logon" cannot coexist with "password never expires"** — AD
  rejects setting both; they are contradictory. (Relevant to service accounts.)
- **Reading `pwdLastSet` literally** — a blank/0 value is not "no password," it means the
  forced-change flag is set.
- **Repeated change prompts** — if a user is prompted every login, check the password is
  actually being saved successfully and that no policy is forcing immediate expiry.

### Escalation Path
- User genuinely cannot complete the change (error at the change-password screen) → check
  the applicable FGPP (the new password must satisfy length/complexity) and any "user
  cannot change password" flag → escalate to **Tier 2** if unresolved.

### Evidence Captured
| Evidence | File |
|---|---|
| ADUC Account tab (flag ticked) | `Scenario 6 ADUC first logon flag.png` |
| PowerShell flag state before/after | `Scenario 6 first logon flag.png` |

---
