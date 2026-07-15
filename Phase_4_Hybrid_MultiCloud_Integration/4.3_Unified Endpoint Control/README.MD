# Phase 4.3 — Unified Endpoint Control (Microsoft Intune)

**Objective:** Bring the hybrid-joined Windows 11 workstation under cloud-based management with Microsoft Intune using an automated enrolment pattern, then author and deploy real device compliance and configuration controls (BitLocker, USB mass-storage restriction) and enforce them through Conditional Access — demonstrating Zero Trust endpoint enforcement, not just policy authoring.

**Depends on Phase 4.2:** the device must exist in Entra ID (hybrid joined). Satisfied — `WIN11-CLIENT01` is Microsoft Entra hybrid joined.

---

## 1. Concept — MDM, auto-enrolment, and why it's "Zero Trust"

**Mobile Device Management (MDM)** is cloud-based control of an endpoint: Intune pushes configuration, security baselines, and compliance rules to the device and continuously reports its state back. In a Zero Trust model, a device earns access by *proving it is healthy* — not by sitting inside a trusted network. Intune is the mechanism that both enforces "healthy" and reports it to Conditional Access.

**Automatic enrolment** means a device becomes Intune-managed on its own, with no user clicking "enrol." For a Microsoft Entra hybrid joined device this needs **two** things working together:

1. **A cloud switch** — Entra must know Intune is the MDM authority and which users may auto-enrol (MDM user scope).
2. **A device instruction** — a Group Policy telling the domain-joined machine to enrol into Intune using its Entra credentials.

Switch + GPO = automatic enrolment "without manual intervention," exactly as the spec requires.

*Interview relevance (Endpoint/MDM Administrator, and National Grid-type roles):* auto-enrolment, compliance baselines, and Conditional Access device gating are core modern endpoint-management skills employers ask about directly.

---

## 2. Auto-enrolment configured

### 2.1 Cloud switch — MDM user scope

In **Entra → Mobility (MDM and MAM) → Microsoft Intune**, set **MDM user scope = All** so any licensed user's Windows device can auto-enrol (only the E5-licensed pilot users can actually enrol, since enrolment consumes an Intune licence). Default MDM Terms of Use / Discovery / Compliance URLs retained; MAM/WIP scope left None.

![MDM user scope set to All in Entra](intune-mdm-user-scope.png)
*Evidence 1 — Intune set as MDM authority with auto-enrolment scope = All.*

### 2.2 Device instruction — auto-enrolment Group Policy

Created a **Workstations** OU and moved `WIN11-CLIENT01` into it (keeps the policy off the domain controller — a DC is never enrolled into Intune). Created and linked GPO **Intune-Auto-Enrollment** to the Workstations OU, with:

**Computer Configuration → Administrative Templates → Windows Components → MDM → "Enable automatic MDM enrollment using default Azure AD credentials" = Enabled.**

![Auto-enrollment GPO enabled and linked to Workstations OU](02-intune-autoenroll-gpo.png)
*Evidence 2 — auto-enrolment GPO enabled and scoped to the Workstations OU.*

**Design note — targeting (principle: least scope / blast radius).** The GPO is linked to a dedicated Workstations OU rather than the domain root, so it applies only to client machines and can never pull the domain controller into MDM. The device was moved into that OU for the policy to reach it (GPOs link to OUs, not the default `Computers` container).

---
## 3. Endpoint controls — authored & deployed

Three tenant-side controls were authored and assigned. Together they define what a "healthy" device is (compliance), harden it (configuration), and enforce the verdict (Conditional Access).

### 3.1 Compliance policy — require BitLocker

Intune Windows compliance policy **`WIN-Compliance-Baseline`** requiring **BitLocker** and **Secure Boot**, assigned to **All devices**. This is Intune's *definition of a healthy device*; its Compliant / Non-Compliant verdict is what Conditional Access reads.

![BitLocker compliance policy](compliance-policy-bitlocker.png)
*Evidence 3 — compliance baseline requiring BitLocker + Secure Boot.*

### 3.2 Configuration profile — block USB mass storage

Device-restrictions profile **`WIN-USB-Block`** setting **Removable storage = Block**, assigned to **All devices** — closing the classic data-exfiltration and malware-ingress path of USB mass-storage devices.

![USB mass-storage block configuration profile](config-profile-usb-block.png)
*Evidence 4 — removable/USB mass storage blocked via configuration profile.*

### 3.3 Conditional Access enforcement — the Zero Trust gate

Conditional Access policy **CA02 (block non-compliant devices)** was moved from **Report-only** to **On**, scoped to the pilot users, with the break-glass Global Admin excluded. This turns policy *authoring* into policy *enforcement*: a device that fails the compliance baseline is now actively **blocked** from resources, while a compliant device passes.

![CA02 enforced — Enable policy On](ca02-enforced.png)
*Evidence 5 — Conditional Access enforcing device compliance (Zero Trust gate live).*

**Principle named — Zero Trust / verify explicitly.** Access is granted per-device based on continuously-evaluated health, not on network location. Compliance policy defines health; Conditional Access enforces it; together they are the enforcement loop, not just documentation.
