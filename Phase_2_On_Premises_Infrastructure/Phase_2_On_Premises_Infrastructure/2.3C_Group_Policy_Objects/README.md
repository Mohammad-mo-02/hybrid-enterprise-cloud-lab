# Phase 2.3C: Group Policy Objects (GPO)

**Purpose:** Create, configure, link and verify three Group Policy Objects that enforce
consistent security configuration across the enterprise: a user workstation lock policy,
an administrative/removable-media restriction policy, and a domain-wide security/audit
baseline. Demonstrates centralised configuration management and the principle that a
policy is defined once and enforced everywhere it is linked.

**Environment:** `corp.infralab.local` | Domain Controller: `WS2022-DC01`
**Tooling:** Group Policy Management Console (GPMC) + PowerShell `GroupPolicy` module

### Group Policy core concepts (reference)
- A **GPO** is a container of settings, linked to an OU; all users/computers in that OU
  (and child OUs, via **inheritance**) receive it.
- Every GPO has two halves: **Computer Configuration** (applies to machines, `HKLM`) and
  **User Configuration** (applies to users, `HKCU`). *Where* it is linked and *which*
  half is configured must match the target.
- Settings are ultimately registry values pushed to clients; the GPO **version number**
  increments on each change so clients know to re-pull it.

---

## GPO 1: User Workstation Lock Policy

### Objective
Enforce an automatic, password-protected screen lock after 15 minutes of inactivity for
all standard users, mitigating the **unattended workstation** threat (an unlocked, walked-
away-from machine being used by a passer-by as that user). Physical-layer **defence in
depth**; commonly a compliance requirement.

### Settings configured (User Configuration — HKCU)
| Setting | Registry value | Value | Meaning |
|---|---|---|---|
| Enable screen saver | `ScreenSaveActive` | 1 | Turns the lock mechanism on |
| Password protect | `ScreenSaverIsSecure` | 1 | Requires password to dismiss (without this the lock is useless) |
| Idle timeout | `ScreenSaveTimeOut` | 900 | Locks after 900 seconds (15 minutes) |

All three are required together — screen saver on + password required + timeout = a real
lock. The `HKCU` path confirms these are **user-side** settings (they follow the user).

### Implementation — PowerShell
```powershell
# 1. Create the GPO
New-GPO -Name "User-Workstation-Lock-Policy" -Comment "Enforces password-protected screen lock after 15 minutes idle. Phase 2.3C."

# 2. Configure the three settings
$gpoName = "User-Workstation-Lock-Policy"
$key = "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop"
Set-GPRegistryValue -Name $gpoName -Key $key -ValueName "ScreenSaveActive"    -Type String -Value "1"
Set-GPRegistryValue -Name $gpoName -Key $key -ValueName "ScreenSaverIsSecure" -Type String -Value "1"
Set-GPRegistryValue -Name $gpoName -Key $key -ValueName "ScreenSaveTimeOut"   -Type String -Value "900"

# 3. Link to the Departments OU (inherited by all department sub-OUs)
New-GPLink -Name "User-Workstation-Lock-Policy" `
    -Target "OU=Departments,OU=Administration,DC=corp,DC=infralab,DC=local" `
    -LinkEnabled Yes
```

### Why link at the Departments OU
Linking once at the parent **Departments** OU means all twelve department child OUs
(Finance, HR, IT, Sales, …) inherit the policy automatically — efficient, correct, and a
direct demonstration of **GPO inheritance** (policy flows down the OU tree).

### Verification — GPMC (GUI)
GPMC → `corp.infralab.local` → Administration → **Departments** → **Linked Group Policy
Objects** tab shows `User-Workstation-Lock-Policy`, **Link Enabled: Yes**, **GPO Status:
Enabled**, Link Order 1.

![GPO1 linked in GPMC](GPO1%20workstation%20lock%20GPMC.png)

### Verification — PowerShell
```powershell
Get-GPInheritance -Target "OU=Departments,OU=Administration,DC=corp,DC=infralab,DC=local" |
    Select-Object -ExpandProperty GpoLinks | Select-Object DisplayName, Enabled, Order

Get-GPRegistryValue -Name "User-Workstation-Lock-Policy" `
    -Key "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" |
    Select-Object ValueName, Value
```

![GPO1 settings verified](GPO1%20workstation%20lock%20verify.png)

### Note on testing
This environment is a single domain controller with no separate client workstation. The
GPO is fully created, configured, linked and verified. Visible end-user application
(screen locking on a client) would be demonstrated on a domain-joined Windows client when
provisioned (Phase 4.2). Building, linking and verifying on the DC fully demonstrates GPO
management competency.

### Evidence Captured
| Evidence | File |
|---|---|
| GPO linked in GPMC (Departments OU) | `GPO1 workstation lock GPMC.png` |
| Link + settings verified via PowerShell | `GPO1 workstation lock verify.png` |

---
