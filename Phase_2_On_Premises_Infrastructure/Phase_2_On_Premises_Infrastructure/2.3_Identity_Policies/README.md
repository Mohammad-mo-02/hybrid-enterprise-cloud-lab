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
