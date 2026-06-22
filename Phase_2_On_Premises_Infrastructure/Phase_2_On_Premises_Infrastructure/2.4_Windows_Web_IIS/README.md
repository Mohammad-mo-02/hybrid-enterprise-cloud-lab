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
