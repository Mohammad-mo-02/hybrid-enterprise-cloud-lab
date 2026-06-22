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
## GPO 2: Removable Media (USB) Restriction Policy

### Objective
Block USB mass-storage devices (read and write) across workstations to close two threat
vectors at once:
- **Data exfiltration** — copying sensitive data onto removable media and removing it.
- **Malware introduction** — auto-running malware from an unknown/planted USB device.
A standard enterprise control and a frequent compliance requirement (PCI-DSS, ISO 27001).

### Why this is a COMPUTER policy (contrast with GPO 1)
USB blocking must apply to the **machine regardless of who logs in**, so it is configured
under **Computer Configuration** (`HKLM` — Local Machine), not User Configuration. This is
the opposite half of the GPO model from GPO 1 (which was a user/`HKCU` policy). Because it
targets computers, it is linked to the **Devices** OU (where computer objects live);
linking a computer policy to a user OU would have no effect.

### Settings configured (Computer Configuration — HKLM)
| Setting | Registry key | Value | Meaning |
|---|---|---|---|
| Disable USB storage driver | `...\Services\USBSTOR` → `Start` | 4 | 3 = enabled, **4 = disabled** |
| Deny all removable read | `...\RemovableStorageDevices` → `Deny_All` | 1 | Blocks read access to removable classes |
| Deny removable write | `...\RemovableStorageDevices\{53f5630d-...}` → `Deny_Write` | 1 | Explicitly blocks writing to removable disks |

Note these use the `DWord` (numeric) registry type, not `String` — the type must match
what Windows expects or the setting silently fails to apply.

### Implementation — PowerShell
```powershell
# 1. Create the GPO
New-GPO -Name "Admin-Removable-Media-Restriction" -Comment "Blocks USB mass-storage devices (read and write). Computer policy. Phase 2.3C."

# 2. Configure the computer-side USB block (HKLM)
$gpoName = "Admin-Removable-Media-Restriction"
Set-GPRegistryValue -Name $gpoName -Key "HKLM\SYSTEM\CurrentControlSet\Services\USBSTOR" -ValueName "Start" -Type DWord -Value 4
Set-GPRegistryValue -Name $gpoName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices" -ValueName "Deny_All" -Type DWord -Value 1
Set-GPRegistryValue -Name $gpoName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices\{53f5630d-b6bf-11d0-94f2-00a0c91efb8b}" -ValueName "Deny_Write" -Type DWord -Value 1

# 3. Link to the Devices OU (where computer objects live)
New-GPLink -Name "Admin-Removable-Media-Restriction" `
    -Target "OU=Devices,OU=Administration,DC=corp,DC=infralab,DC=local" `
    -LinkEnabled Yes
```

### Verification — GPMC (GUI)
GPMC → `corp.infralab.local` → Administration → **Devices** → Linked Group Policy Objects
shows `Admin-Removable-Media-Restriction`, Link Enabled: Yes, GPO Status: Enabled.

![GPO2 linked in GPMC](GPO2%20USB%20restriction%20GPMC.png)

### Verification — PowerShell
```powershell
Get-GPInheritance -Target "OU=Devices,OU=Administration,DC=corp,DC=infralab,DC=local" |
    Select-Object -ExpandProperty GpoLinks | Select-Object DisplayName, Enabled, Order

Get-GPRegistryValue -Name "Admin-Removable-Media-Restriction" `
    -Key "HKLM\SYSTEM\CurrentControlSet\Services\USBSTOR" -ValueName "Start"
```
Confirms the link on the Devices OU and `Start = 4` (USB storage disabled).

![GPO2 settings verified](GPO2%20USB%20restriction%20verify.png)

### Teaching point — reading GPO version numbers
When the settings were written, the GPO's **ComputerVersion** incremented (1→2→3) while
**UserVersion stayed at 0** — the mirror image of GPO 1. The version counters reveal which
half of a GPO carries settings: rising ComputerVersion = computer settings; rising
UserVersion = user settings. A key diagnostic skill (see Scenario 9).

### Note on testing
USB blocking applies to computer objects in the Devices OU. With no separate client
present, the GPO is created, configured, linked and verified on the DC; a domain-joined
Windows client placed in the Devices OU (Phase 4.2) would inherit the block automatically.

### Evidence Captured
| Evidence | File |
|---|---|
| GPO linked in GPMC (Devices OU) | `GPO2 USB restriction GPMC.png` |
| Link + USBSTOR setting verified | `GPO2 USB restriction verify.png` |

---
