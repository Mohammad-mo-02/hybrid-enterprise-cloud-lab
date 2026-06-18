# ==============================================================================
# Script: AD-BulkProvisioning-Prod.ps1 (UPDATED - Standard Schema Only)
# Objective: Phase 2.2 Bulk Provisioning of 300 Enterprise Users
# Domain: corp.infralab.local
# ==============================================================================

Import-Module ActiveDirectory

# --- Configuration Variables ---
$csvPath = "C:\Scripts\users-data.csv"
$logDate = Get-Date -Format "yyyyMMdd_HHmmss"
$transcriptPath = "C:\Scripts\Provisioning-Transcript-$logDate.txt"
$reportPath = "C:\Scripts\Provisioning-Report-$logDate.csv"
$domainPath = "DC=corp,DC=infralab,DC=local"

# --- Start Logging ---
Start-Transcript -Path $transcriptPath -NoClobber

Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "   Active Directory Bulk Provisioning Script" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan

# --- Pre-Flight Checks ---
if (-not (Test-Path $csvPath)) {
    Write-Host "[X] ERROR: CSV file not found at $csvPath. Aborting execution." -ForegroundColor Red
    Stop-Transcript
    exit
}

$users = Import-Csv $csvPath

# --- Metrics Tracking ---
$stats = @{
    Created = 0
    Skipped = 0
    Failed = 0
}
$reportData = @()

# --- Helper Function: Generate Secure Passwords ---
Function Get-RandomComplexPassword {
    $upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.ToCharArray() | Get-Random -Count 3
    $lower = 'abcdefghijklmnopqrstuvwxyz'.ToCharArray() | Get-Random -Count 5
    $nums  = '0123456789'.ToCharArray() | Get-Random -Count 3
    $specs = '!@#$%^&*'.ToCharArray() | Get-Random -Count 3
    
    $combined = $upper + $lower + $nums + $specs
    $shuffled = $combined | Sort-Object {Get-Random}
    return ($shuffled -join '')
}

# --- Main Execution Loop ---
foreach ($user in $users) {
    # 1. Sanitize Inputs
    $firstName = $user.FirstName.Trim()
    $lastName = $user.LastName.Trim()
    $dept = $user.Department.Trim()
    $managerName = $user.Manager.Trim()
    $title = $user.Title.Trim()
    $office = $user.Office.Trim()
    $costCenter = $user.CostCenter.Trim()

    # 2. Construct Naming & Paths
    $samAccountName = "$($firstName.ToLower()).$($lastName.ToLower())"
    $upn = "$samAccountName@corp.infralab.local"
    $displayName = "$firstName $lastName"
    $targetOU = "OU=$dept,OU=Departments,OU=Administration,$domainPath"
    
    $statusMessage = ""

    try {
        # 3. Idempotency Check
        if (Get-ADUser -Filter "SamAccountName -eq '$samAccountName'" -ErrorAction SilentlyContinue) {
            Write-Host "[-] SKIPPED: User $samAccountName already exists." -ForegroundColor Yellow
            $stats.Skipped++
            $statusMessage = "Skipped - Already Exists"
        } 
        else {
            # 4. Generate Credentials
            $plainPassword = Get-RandomComplexPassword
            $securePassword = ConvertTo-SecureString $plainPassword -AsPlainText -Force

            # 5. Resolve Manager DN
            $managerDN = $null
            if (![string]::IsNullOrWhiteSpace($managerName)) {
                $managerObj = Get-ADUser -Filter "DisplayName -eq '$managerName'" -ErrorAction SilentlyContinue
                if ($managerObj) {
                    $managerDN = $managerObj.DistinguishedName
                } else {
                    Write-Host "[!] WARNING: Manager '$managerName' not found. Linking skipped for $samAccountName." -ForegroundColor DarkYellow
                }
            }

            # 6. Build Standard User Parameters (NO Extension Attributes)
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

            if ($managerDN) {
                $adParams.Add('Manager', $managerDN)
            }

            # 7. Execute Creation
            New-ADUser @adParams -ErrorAction Stop
            
            Write-Host "[+] SUCCESS: Created $samAccountName in OU=$dept" -ForegroundColor Green
            $stats.Created++
            $statusMessage = "Success"
        }
    } 
    catch {
        $errorMsg = $_.Exception.Message
        Write-Host "[X] FAILED: Could not create $samAccountName. Error: $errorMsg" -ForegroundColor Red
        $stats.Failed++
        $statusMessage = "Failed - $errorMsg"
    }

    # 8. Append to CSV Report Data
    $reportData += [PSCustomObject]@{
        Username   = $samAccountName
        Department = $dept
        Office     = $office
        Status     = $statusMessage
    }
}

# --- Post-Execution Reporting ---
$reportData | Export-Csv -Path $reportPath -NoTypeInformation

Write-Host "`n===================================================" -ForegroundColor Cyan
Write-Host "   PROVISIONING SUMMARY" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "Total CSV Rows Processed : $($users.Count)"
Write-Host "Successfully Created     : $($stats.Created)" -ForegroundColor Green
Write-Host "Skipped (Already Exists) : $($stats.Skipped)" -ForegroundColor Yellow
Write-Host "Failed to Create         : $($stats.Failed)" -ForegroundColor Red
Write-Host "---------------------------------------------------"
Write-Host "Detailed execution log saved to: $transcriptPath"
Stop-Transcript