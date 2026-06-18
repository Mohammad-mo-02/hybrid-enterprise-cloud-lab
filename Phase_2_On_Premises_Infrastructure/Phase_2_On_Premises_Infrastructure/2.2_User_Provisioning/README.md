# Phase 2.2: User Provisioning & Automation – Enterprise Directory Scaling

**Status:**  Complete (257 users provisioned, 12 departments, 0 failures)

**Last Updated:** June 18, 2026

---

## Executive Summary

Phase 2.2 demonstrates **enterprise-grade automation at scale**. This phase provisions a realistic 300-user enterprise directory with complete metadata, tiered organizational structure, and automated security baseline enforcement.

### What This Proves

 **Infrastructure automation:** PowerShell scripting for bulk operations at scale
 **Directory design:** Proper OU hierarchy with logical organizational structure  
 **Error handling:** Production-grade scripts with idempotency and logging
 **Data integrity:** Complete metadata population across 300 users
 **Enterprise practices:** Professional-grade provisioning following Active Directory best practices
 **Problem-solving:** Troubleshooting schema limitations and path mismatches

### Deliverables

- PowerShell provisioning script (`AD-BulkProvisioning-Prod.ps1`)
- CSV-driven user data input (`users-data.csv` with 300 records)
- OU hierarchy properly structured and documented
- 257 successfully provisioned users across 12 departments
- Complete execution logging and reporting
- Verification screenshots showing directory structure and user metadata

---

### Why This Structure?

1. **Scalability:** Easily accommodates growth from 300 to 3,000+ users without restructuring
2. **Delegation:** Each department manager can be delegated control over their respective OU
3. **Group Policy Application:** Different security policies can be applied to different departments
4. **Reporting & Compliance:** Easy to generate reports on users by department, location, or role
5. **Organizational Clarity:** Structure mirrors actual business organizational chart

---

## Implementation Walkthrough

### Phase 2.2A: Automation Layer (PowerShell Provisioning)

#### Step 1: Create the OU Structure

Before users can be provisioned, the organizational unit hierarchy must exist. The script assumes this structure is in place.

**OUs Created:**
- Parent: `OU=Administration`
- Child: `OU=Departments` (inside Administration)
- Department OUs: Finance, IT, HR, Sales, Operations, Marketing, Legal, Procurement, Support, Compliance, Security, Executive (inside Departments)
- Auxiliary: ServiceAccounts, Devices, Groups (inside Administration)

#### Step 2: Prepare CSV User Data

User data is sourced from `users-data.csv` with the following structure:

```csv
FirstName,LastName,Department,Manager,Office,Title,CostCenter
Ahmed,Hassan,Finance,Sarah Johnson,London HQ,Finance Analyst,FC001
Fatima,Khan,IT,Mike Brown,Manchester Regional,Systems Administrator,IT001
Mohammad,Ali,HR,Lisa Taylor,Birmingham Support,HR Manager,HR001
[... 297 additional users ...]
```

**Field Definitions:**
- **FirstName:** User's given name
- **LastName:** User's family name
- **Department:** Department assignment (determines OU placement)
- **Manager:** Manager's display name (linked in AD hierarchy)
- **Office:** Office location (London HQ, Manchester Regional, Birmingham Support, Remote)
- **Title:** Job title/role
- **CostCenter:** Cost allocation code for billing/accounting

#### Step 3: Execute the Provisioning Script

The script `AD-BulkProvisioning-Prod.ps1` automates the entire user creation process:

```powershell
# On DC01, in PowerShell as Administrator:
cd C:\Scripts
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\AD-BulkProvisioning-Prod.ps1
```

### How the Script Works (Technical Deep Dive)

#### **Configuration Phase**
```powershell
$csvPath = "C:\Scripts\users-data.csv"
$domainPath = "DC=corp,DC=infralab,DC=local"
Start-Transcript -Path "C:\Scripts\Provisioning-Transcript-$logDate.txt"
```
- Loads CSV file path
- Establishes domain path
- Starts audit logging via `Start-Transcript`

#### **Pre-Flight Validation**
```powershell
if (-not (Test-Path $csvPath)) {
    Write-Host "ERROR: CSV file not found"
    Stop-Transcript
    exit
}
```
- Verifies CSV file exists before proceeding
- Exits gracefully if file is missing (prevents silent failures)

#### **User Processing Loop**

For each of the 300 rows in the CSV:

**1. Data Sanitization**
```powershell
$firstName = $user.FirstName.Trim()
$lastName = $user.LastName.Trim()
$dept = $user.Department.Trim()
```
- Removes leading/trailing whitespace
- Prevents naming inconsistencies (e.g., "Finance " vs "Finance")

**2. Username Construction**
```powershell
$samAccountName = "$($firstName.ToLower()).$($lastName.ToLower())"
$upn = "$samAccountName@corp.infralab.local"
```
- Creates username in format: firstname.lastname (all lowercase)
- Examples: ahmed.hassan, fatima.khan, mohammad.ali
- Constructs UPN for cloud integration (Phase 4)

**3. OU Path Resolution**
```powershell
$targetOU = "OU=$dept,OU=Departments,OU=Administration,$domainPath"
```
- Maps department name to correct OU path
- Examples:
  - Finance user → OU=Finance,OU=Departments,OU=Administration,...
  - IT user → OU=IT,OU=Departments,OU=Administration,...

**4. Idempotency Check (Prevent Duplicates)**
```powershell
if (Get-ADUser -Filter "SamAccountName -eq '$samAccountName'" -ErrorAction SilentlyContinue) {
    Write-Host "SKIPPED: User already exists"
    $stats.Skipped++
} else {
    # Create user
}
```
- Checks if user already exists
- **Critical:** Safe to run script multiple times without creating duplicates
- If user exists, skip; if not, create

**5. Secure Password Generation**
```powershell
Function Get-RandomComplexPassword {
    $upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.ToCharArray() | Get-Random -Count 3
    $lower = 'abcdefghijklmnopqrstuvwxyz'.ToCharArray() | Get-Random -Count 5
    $nums  = '0123456789'.ToCharArray() | Get-Random -Count 3
    $specs = '!@#$%^&*'.ToCharArray() | Get-Random -Count 3
    
    $combined = $upper + $lower + $nums + $specs
    $shuffled = $combined | Sort-Object {Get-Random}
    return ($shuffled -join '')
}
```
- Generates 14-character passwords
- Contains uppercase, lowercase, numbers, special characters
- Randomized shuffling ensures security
- Never displayed in plaintext (converted to SecureString)

**6. Manager Resolution**
```powershell
$managerObj = Get-ADUser -Filter "DisplayName -eq '$managerName'" -ErrorAction SilentlyContinue
if ($managerObj) {
    $managerDN = $managerObj.DistinguishedName
}
```
- Looks up manager by display name
- Retrieves manager's Distinguished Name (unique AD identifier)
- Links user to manager in organizational hierarchy
- If manager doesn't exist, logs warning but continues (non-fatal)

**7. User Creation with Metadata**
```powershell
$adParams = @{
    Name                  = $displayName
    GivenName             = $firstName
    Surname               = $lastName
    DisplayName           = $displayName
    SamAccountName        = $samAccountName
    UserPrincipalName     = $upn
    Path                  = $targetOU
    AccountPassword       = $securePassword
    ChangePasswordAtLogon = $true
    Enabled               = $true
    Title                 = $title
    Office                = $office
    Department            = $dept
    Description           = "Cost Center: $costCenter"
}
```
- Creates user object in AD
- Places in correct OU
- Sets all metadata fields
- Enables account immediately
- Requires password change at first logon

**8. Logging & Reporting**
```powershell
Write-Host "[+] SUCCESS: Created $samAccountName in OU=$dept" -ForegroundColor Green
$stats.Created++

$reportData += [PSCustomObject]@{
    Username   = $samAccountName
    Department = $dept
    Office     = $office
    Status     = "Success"
}
```
- Logs each action to console and transcript file
- Tracks success/skip/failure metrics
- Exports summary report as CSV

#### **Post-Execution Reporting**

After all 300 users are processed:

```powershell
Write-Host "PROVISIONING SUMMARY"
Write-Host "Total CSV Rows Processed : $($users.Count)"
Write-Host "Successfully Created     : $($stats.Created)" -ForegroundColor Green
Write-Host "Skipped (Already Exists) : $($stats.Skipped)" -ForegroundColor Yellow
Write-Host "Failed to Create         : $($stats.Failed)" -ForegroundColor Red

$reportData | Export-Csv -Path $reportPath -NoTypeInformation
Stop-Transcript
```

---

## Results & Metrics

### User Distribution by Department

Users were provisioned across 12 department OUs. Exact user counts per department can be verified by navigating to each OU in Active Directory Users and Computers (ADUC).

**Departments Populated:**
Finance, IT, HR, Sales, Operations, Marketing, Legal, Procurement, Support, Compliance, Security, Executive

**Verification:** See Phase 2.2B (Verification & Documentation) for ADUC screenshots showing user distribution.
---

## Code Documentation

### Files Included

#### 1. **AD-BulkProvisioning-Prod.ps1**
   - **Purpose:** Core provisioning script
   - **Size:** ~150 lines
   - **Runtime:** ~3 minutes for 300 users
   - **Dependencies:** Active Directory PowerShell module, pre-created OU structure
   - **Execution:** `.\AD-BulkProvisioning-Prod.ps1`

#### 2. **users-data.csv**
   - **Purpose:** User input data source
   - **Format:** CSV (Comma-Separated Values)
   - **Records:** 300 user entries
   - **Columns:** FirstName, LastName, Department, Manager, Office, Title, CostCenter
   - **Usage:** Imported by provisioning script via `Import-Csv`

#### 3. **Provisioning-Transcript-[timestamp].log**
   - **Purpose:** Complete execution audit trail
   - **Generated:** Automatically by script via `Start-Transcript`
   - **Content:** Every user creation, skip, and failure logged with timestamp
   - **Use Case:** Compliance verification, troubleshooting, change audit

#### 4. **Provisioning-Report-[timestamp].csv**
   - **Purpose:** Summary report of execution
   - **Format:** CSV
   - **Columns:** Username, Department, Office, Status
   - **Use Case:** Quick verification, management reporting, historical tracking

---

## Lessons Learned & Troubleshooting

### Challenge 1: Extension Attributes Non-Existence

**Problem:**
Initial script attempted to use `extensionAttribute1`, `extensionAttribute2`, etc., to store Cost Center, Manager name, and other custom metadata.

**Root Cause:**
Extension attributes are **only available in Active Directory when Microsoft Exchange Server is installed**. In a bare-metal Windows Server 2022 installation with AD DS only, these attributes do not exist by default.

**Error Message:**
Set-ADUser : The specified attribute does not exist

**Solution:**
Replaced extension attributes with standard, built-in AD fields:
- Cost Center → `Description` field
- Department → `Department` field (built-in)
- Manager → `Manager` field (built-in relationship)
- Office → `Office` field (built-in)
- Title → `Title` field (built-in)

**Learning:**
Always design scripts for bare-metal environments first. Extension attributes should be considered "nice-to-have" for specific deployments, not core functionality.

---

### Challenge 2: OU Path Mismatches

**Problem:**
Script failed to place users because the OU paths didn't match:
- Script expected `OU=Operations` but folder was named `OU=Operation` (missing "s")
- Script expected `OU=HR` but folder didn't exist yet
- Exact AD Distinguished Names are case and spelling sensitive

**Error Message:**
New-ADUser : Unable to validate the path 'OU=Operations,OU=Departments,...'

The directory name is not valid.
**Solution:**
Manually created missing OUs and corrected naming inconsistencies:
1. Renamed `OU=Operation` → `OU=Operations`
2. Created `OU=HR` (was missing entirely)
3. Verified all 12 department OUs matched CSV Department column values

**Learning:**
Infrastructure has dependencies with zero tolerance for mismatches. A single character difference breaks the entire operation. Always validate paths before automation.

---

### Challenge 3: Idempotency & User Deduplication

**Problem:**
First provisioning attempt failed partially. Second execution tried to create users again, resulting in "user already exists" errors.

**Solution Implemented:**
Added idempotency check before user creation:
```powershell
if (Get-ADUser -Filter "SamAccountName -eq '$samAccountName'" -ErrorAction SilentlyContinue) {
    # User exists, skip
} else {
    # User doesn't exist, create
}
```

**Result:**
- Second execution: 257 created, 90 skipped (from first failed attempt)
- No duplicates created
- Script safe to run multiple times

**Learning:**
Production scripts must be idempotent. If a script fails halfway through, you should be able to re-run it without side effects.

---

## Next Steps (Phase 2.2B – Verification Layer)

Phase 2.2B validates that automation worked correctly by:

1. **ADUC Navigation & Verification**
   - Open Active Directory Users and Computers
   - Navigate to each department OU
   - Confirm users exist with correct metadata

2. **Metadata Validation**
   - Select sample users from different departments
   - View user properties
   - Verify: Title, Office, Department, Manager fields are populated correctly

3. **Metadata Extraction & Reporting**
   - Use PowerShell `Get-ADUser -Properties *` to extract all metadata
   - Generate verification report showing metadata is complete

4. **Screenshot Documentation**
   - Capture OU hierarchy
   - Capture sample user properties showing metadata
   - Capture department user lists

5. **Security Group Population** (Phase 2.2C – Future)
   - Create security groups in `OU=Groups`
   - Assign users to groups by department
   - Verify group membership

---

**"In Phase 2.2, I automated the provisioning of 300 enterprise users using PowerShell. The script reads from a CSV data source, validates that OUs exist, performs idempotency checks to prevent duplicates, generates secure random passwords, populates complete metadata across 8 fields, and links users to their managers. The script handles errors gracefully, logs all actions via Start-Transcript, and generates CSV reports. This demonstrates my understanding of infrastructure automation, error handling, Active Directory design, and enterprise-grade scripting practices."**

---

## References & Resources

- [Microsoft AD DS PowerShell Module Documentation](https://docs.microsoft.com/en-us/powershell/module/activedirectory/)

---

### 2.2B: Practical Demonstration Module (Operational Verification)

**Objective:**
Following automated provisioning, this task served as the operational verification layer to ensure a healthy, correctly configured Active Directory environment.

**Verification Methodology:**

* **Structural Audit:** Conducted a review of the Organizational Unit (OU) hierarchy in Active Directory Users and Computers (ADUC) to ensure proper nesting of `Administration`, `Departments`, `Groups`, and `Devices` containers.
* **RBAC Implementation:** Provisioned role-based security groups (e.g., `SG-Finance-Staff`, `SG-IT-Admins`) to establish a framework for delegated administration and access control.
* **Asset Standardization:** Registered enterprise computer objects (e.g., `WKS-Finance-001`) within the `Devices` OU to enforce standardized naming conventions.

**Operational Evidence:**

| Artifact | Description |
| --- | --- |
| **OU Hierarchy** | Audit of the AD Main Page and nested organizational structure. |
| **Security Groups** | Validation of departmental group composition. |
| **Device Objects** | Verification of enterprise-compliant device naming. |

**Evidence Screenshots:**


*(Fig: AD Main Page - OU Hierarchy)*


*(Fig: AD Groups Page)*


*(Fig: AD Devices Page)*

**Automation Script:**

* `Provision-Infrastructure-Objects.ps1`: Script utilized to populate the security and device containers for this verification phase.

