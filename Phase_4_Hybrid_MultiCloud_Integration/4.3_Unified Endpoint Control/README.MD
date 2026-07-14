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

## 3. Status — honest position

**Configured and verified:**
- Intune set as MDM authority; MDM user scope = All (Evidence 1).
- Auto-enrolment GPO enabled and correctly scoped to the Workstations OU with the device inside it (Evidence 2).

**Open item — device enrolment pending:** the workstation had not completed enrolment into Intune at time of writing (Intune → Devices showed 0 managed devices). This is **not a configuration gap** — both halves of the auto-enrolment mechanism are in place and correct. The trigger for a hybrid device is a **licensed pilot user signing in once** on the workstation, and that interactive sign-in was blocked by a VMware console/credential issue on the VM. Enrolment is a short close-out once a licensed sign-in succeeds.

**Lesson documented:** *Device Credential* auto-enrolment was trialled first (to avoid the user sign-in) but proved unreliable for hybrid → Intune-only — it is intended for co-management (SCCM) scenarios. Reverted to *User Credential*, which is the dependable path but requires a licensed user to sign in. Recurring principle: match the enrolment credential type to the scenario; the "clever shortcut" cost time.

---

## 4. Remaining deliverables in this phase

To be completed and evidenced next (tenant-side, no device required to author):

1. **Compliance policy** — require BitLocker + Secure Boot (`WIN-Compliance-Baseline`).
2. **Configuration profile** — block USB mass storage (`WIN-USB-Block`).
3. **Conditional Access enforcement** — move CA02 (block non-compliant devices) from report-only to enforced, demonstrating Zero Trust gating.
4. **Device enrolment verification** — confirm `WIN11-CLIENT01` shows *Managed by: MDM* in Intune once a licensed sign-in completes, then observe compliance evaluation and CA outcome.

---

*Environment: WIN11-CLIENT01 (Windows 11 Enterprise, hybrid joined) · DC01 (WS2022) · Entra tenant df8403b0-4503-4df0-9f25-40f6c0d0a932 · M365 E5 trial (expires 2026-08-10).*
