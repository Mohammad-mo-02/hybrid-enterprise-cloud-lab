# Phase 2.4: Windows Web Operations (IIS)

**Objective:** Deploy a functional enterprise corporate web service on Windows Server using
IIS, then harden its TLS configuration to the Elite Standard (disable legacy protocols,
enforce strong ciphers).

**Environment:** WS2022-DC01 | `corp.infralab.local` | logged in as CORP\Administrator

---

## Part 1: Deploy the IIS Web Service

### Concept
**IIS (Internet Information Services)** is Microsoft's built-in web server role — software
that listens for web requests and serves back content. A web server's content is served
from a physical folder on disk; for the default site this is `C:\inetpub\wwwroot`. Whatever
HTML sits in that folder is what the site serves.

### Implementation — PowerShell (Automation First)
```powershell
# Install the IIS role plus the management console (IIS Manager)
Install-WindowsFeature -Name Web-Server -IncludeManagementTools

# Verify install
Get-WindowsFeature -Name Web-Server | Select-Object Name, DisplayName, InstallState
```
GUI equivalent: Server Manager → Add Roles and Features → Web Server (IIS).

### Verification — service, site, and live request
```powershell
# Web service running?
Get-Service -Name W3SVC | Select-Object Name, Status, StartType

# Sites configured?
Import-Module WebAdministration
Get-Website | Select-Object Name, ID, State, PhysicalPath

# Live request - does it actually serve?
Invoke-WebRequest -Uri "http://localhost" -UseBasicParsing |
    Select-Object StatusCode, StatusDescription
```
Confirmed: `W3SVC` Running / Automatic; Default Web Site Started, serving from
`C:\inetpub\wwwroot`; HTTP request returned **200 (OK)**.

### Custom corporate page
Replaced the stock IIS welcome page with a custom corporate intranet landing page, written
directly into the web root:
```powershell
$html = @'  ... corporate HTML ...  '@
$html | Out-File -FilePath "C:\inetpub\wwwroot\index.html" -Encoding UTF8 -Force
```
`index.html` is served automatically as IIS's default document. Verified: request returned
200, content length 3687 bytes, page title "Infralab Corporate Intranet" — confirming the
custom page (not the default) is being served.

### Key concepts captured
- **`C:\inetpub\wwwroot` is the website** — the on-disk folder IIS serves from.
- **W3SVC** (World Wide Web Publishing Service) is the service that listens for requests.
- **HTTP 200** = success; the standard "request understood, here is the content" response.
- **Server header disclosure:** the response advertised `Server: Microsoft-IIS/10.0`. This
  is information disclosure (tells an attacker the server software/version) and is a
  hardening item addressed in Part 2.

### Evidence Captured
| Evidence | File |
|---|---|
| Rendered corporate intranet page in browser | `2.4 IIS corporate page.png` |

---
## Part 2: TLS Hardening

### Objective
Disable weak/legacy encryption protocols (SSL 2.0, SSL 3.0, TLS 1.0, TLS 1.1) and
explicitly enforce strong TLS (1.2), so the server refuses to encrypt with broken protocols
that are vulnerable to known attacks (POODLE, BEAST). A standard security-audit requirement
(e.g. PCI-DSS mandates disabling weak protocols).

### Core concept — where TLS is configured on Windows
TLS hardening is **not** configured in IIS. Encryption on Windows is handled by **Schannel**
(Secure Channel), an OS-level component that implements SSL/TLS for the *entire* system
(IIS, RDP, and any other TLS service). IIS delegates encryption to Schannel. Schannel is
configured via the **registry**, so hardening it secures every TLS service on the box, not
just IIS. *(Principle: separation of concerns — IIS serves content, Schannel handles
encryption; defence in depth at the OS layer.)*

### The problem with defaults
Before hardening, every protocol showed *"no explicit setting (OS default applies)."* "No
setting" means "Windows decides" — and Windows defaults favour compatibility, leaving older
protocols implicitly available. An attacker can force a connection to **downgrade** to a
weak protocol and break the encryption. The fix is to take **explicit control**: weak
protocols explicitly OFF, strong protocols explicitly ON. *(Principle: no insecure defaults
/ explicit over implicit.)*

### How Schannel protocol control works
Each protocol has a registry path `...\SCHANNEL\Protocols\<protocol>\<Server|Client>` with
two values that work together:
- `Enabled` = 0 (off) / 1 (on)
- `DisabledByDefault` = 1 (not offered) / 0 (offered)

Disable = `Enabled 0` + `DisabledByDefault 1`. Enable = `Enabled 1` + `DisabledByDefault 0`.
Both values are set (belt-and-braces) for both Server and Client roles. *(Principle: defence
in depth — two reinforcing settings.)*

### Implementation — PowerShell
```powershell
$base = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols"

# Disable weak protocols (Server + Client)
foreach ($protocol in @("SSL 2.0","SSL 3.0","TLS 1.0","TLS 1.1")) {
    foreach ($role in @("Server","Client")) {
        $path = "$base\$protocol\$role"
        if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        New-ItemProperty -Path $path -Name "Enabled" -Value 0 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $path -Name "DisabledByDefault" -Value 1 -PropertyType DWord -Force | Out-Null
    }
}

# Explicitly enable TLS 1.2 (Server + Client)
foreach ($role in @("Server","Client")) {
    $path = "$base\TLS 1.2\$role"
    if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
    New-ItemProperty -Path $path -Name "Enabled" -Value 1 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $path -Name "DisabledByDefault" -Value 0 -PropertyType DWord -Force | Out-Null
}
```
GUI/tool equivalent: **IIS Crypto** (Nartac) provides a one-click GUI for the same registry
changes. The PowerShell/registry method is used here to expose and understand every change
(Automation First; no hidden wizard decisions).

### Reboot required
Schannel reads protocol configuration at startup, so a **reboot is required** for changes to
take effect (`Restart-Computer -Force`). The registry holds the change immediately; the
*running* system applies it after restart. *(Real-world note: TLS hardening is scheduled in a
maintenance window because of this reboot.)*

### Risk consideration (blast radius)
Disabling legacy protocols cuts off any client that can *only* speak them. In this isolated
lab all components support TLS 1.2+, so it is safe. In production one would first identify
anything still using TLS 1.0/1.1 before disabling — the "what breaks if I remove this?"
discipline.

### Verification (after reboot)
Registry re-read confirms the persistent state:

| Protocol | Before | After |
|---|---|---|
| SSL 2.0 | OS default | **DISABLED** |
| SSL 3.0 | OS default | **DISABLED** |
| TLS 1.0 | OS default | **DISABLED** |
| TLS 1.1 | OS default | **DISABLED** |
| TLS 1.2 | OS default | **ENABLED** |

![TLS state before hardening](2.4%20TLS%20before%20hardening.png)
![TLS state after hardening](2.4%20TLS%20hardened%20state.png)
![Corporate page](2.4%20IIS%20corporate%20page.png)

### Important distinction — hardening ≠ HTTPS enabled
Protocol hardening controls *which* TLS versions Schannel will use *if* a TLS connection
occurs. It does **not** by itself make the site serve HTTPS — that additionally requires a
**certificate** and a **port 443 binding**, which is **Phase 2.8**. A live TLS handshake test
against port 443 currently returns "refused" simply because no HTTPS listener exists yet
(IIS serves HTTP/80 only). The end-to-end handshake test (server accepts TLS 1.2, refuses
1.0/1.1) will be performed in Phase 2.8 once the certificate and 443 binding are in place.

### Evidence Captured
| Evidence | File |
|---|---|
| Rendered corporate intranet page | `2.4 IIS corporate page.png` |
| TLS protocols before hardening (OS defaults) | `2.4 TLS before hardening.png` |
| TLS protocols after hardening (weak disabled, TLS 1.2 enabled) | `2.4 TLS hardened state.png` |

---

## Phase 2.4 Summary
- Deployed IIS and served a custom enterprise corporate intranet page over HTTP (Part 1).
- Hardened Schannel (OS-level TLS): explicitly disabled SSL 2.0/3.0 and TLS 1.0/1.1, and
  explicitly enabled TLS 1.2, for both Server and Client roles; verified persistent through
  reboot (Part 2 — Elite Standard).
- HTTPS binding (certificate + port 443) deferred to Phase 2.8, where end-to-end HTTPS and a
  live handshake test will complete the secure-web-service picture.
