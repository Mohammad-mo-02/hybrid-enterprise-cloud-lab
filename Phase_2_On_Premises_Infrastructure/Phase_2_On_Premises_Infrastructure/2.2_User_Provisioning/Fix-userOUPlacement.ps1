# ==============================================================================
# Script Name: Fix-UserOUPlacement.ps1
# Description: Move users from Administration OU to correct departmental OUs
#              based on their Department attribute (populated during provisioning)
# Revision: Complete production-grade version
# Author: Phase 2.2 Corrective Action
# Date: June 19, 2026
# Status: CORRECTIVE - Addresses missing OU placement in initial provisioning
# ==============================================================================

$domain = "corp.infralab.local"
$domainDN = "DC=corp,DC=infralab,DC=local"

# Start transcript for audit trail
Start-Transcript -Path "C:\Logs\Fix-UserOUPlacement-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt" -Force

Write-Host "=== USER OU PLACEMENT CORRECTION ===" -ForegroundColor Cyan
Write-Host "Phase 2.2 Corrective Action: Moving users to correct departmental OUs" -ForegroundColor Cyan
Write-Host "This script addresses the gap where users were not initially distributed by department" -ForegroundColor Yellow

# Define department mapping (Department attribute -> Target OU)
$departmentMap = @{
    'Administration' = 'OU=Administration,OU=Administration,' + $domainDN
    'Finance' = 'OU=Finance,OU=Departments,OU=Administration,' + $domainDN
    'HR' = 'OU=HR,OU=Departments,OU=Administration,' + $domainDN
    'IT' = 'OU=IT,OU=Departments,OU=Administration,' + $domainDN
    'Sales' = 'OU=Sales,OU=Departments,OU=Administration,' + $domainDN
    'Operations' = 'OU=Operations,OU=Departments,OU=Administration,' + $domainDN
    'Marketing' = 'OU=Marketing,OU=Departments,OU=Administration,' + $domainDN
    'Legal' = 'OU=Legal,OU=Departments,OU=Administration,' + $domainDN
    'Procurement' = 'OU=Procurement,OU=Departments,OU=Administration,' + $domainDN
    'Support' = 'OU=Support,OU=Departments,OU=Administration,' + $domainDN
    'Compliance' = 'OU=Compliance,OU=Departments,OU=Administration,' + $domainDN
    'Security' = 'OU=Security,OU=Departments,OU=Administration,' + $domainDN
    'Executive' = 'OU=Executive,OU=Departments,OU=Administration,' + $domainDN
}

# Verify all target OUs exist before beginning
Write-Host "`n=== PRE-FLIGHT: Verifying Target OUs Exist ===" -ForegroundColor Cyan

$missingOUs = @()
foreach ($dept in $departmentMap.Keys) {
    try {
        $ouPath = $departmentMap[$dept]
        $ou = Get-ADOrganizationalUnit -Identity $ouPath -ErrorAction Stop
        Write-Host "[✓] $dept OU exists" -ForegroundColor Green
    }
    catch {
        Write-Host "[✗] $dept OU missing: $ouPath" -ForegroundColor Red
        $missingOUs += $dept
    }
}

if ($missingOUs.Count -gt 0) {
    Write-Host "`n[CRITICAL] Missing OUs detected. Cannot proceed safely." -ForegroundColor Red
    Write-Host "Missing departments: $($missingOUs -join ', ')" -ForegroundColor Red
    Stop-Transcript
    exit
}

Write-Host "[✓] All target OUs verified. Proceeding with user movement." -ForegroundColor Green

# Get all users currently in Administration OU
Write-Host "`n=== DISCOVERY: Finding Users in Administration OU ===" -ForegroundColor Cyan

$administrationOU = "OU=Administration,$domainDN"

# Use OneLevel scope to get only direct children (not users in sub-OUs like Groups, Devices)
$usersInAdmin = Get-ADUser -SearchBase $administrationOU -SearchScope OneLevel -Filter * -Properties Department, Title, Mail

Write-Host "Found $($usersInAdmin.Count) users directly in Administration OU" -ForegroundColor Yellow

# Initialize counters
$movedCount = 0
$errorCount = 0
$unmappedCount = 0
$skipCount = 0

# Create detailed movement log
$movementLog = @()

Write-Host "`n=== MOVEMENT PHASE: Moving Users to Departmental OUs ===" -ForegroundColor Cyan

foreach ($user in $usersInAdmin) {
    try {
        $userDept = $user.Department
        $userMail = $user.Mail
        $userTitle = $user.Title
        
        # Determine target OU based on Department attribute
        if ([string]::IsNullOrEmpty($userDept)) {
            # Users with no department stay in Administration (these are Tier 0 admin accounts)
            $targetOU = $departmentMap['Administration']
            $unmappedCount++
            Write-Host "[!] $($user.Name) - No department attribute. Keeping in Administration." -ForegroundColor Yellow
            $skipCount++
            continue
        }
        elseif ($departmentMap.ContainsKey($userDept)) {
            $targetOU = $departmentMap[$userDept]
            Write-Host "[+] Moving: $($user.Name) | Dept: $userDept | Title: $userTitle" -ForegroundColor Green
        }
        else {
            Write-Host "[-] Skipping: $($user.Name) - Unknown department: $userDept" -ForegroundColor Red
            $errorCount++
            $movementLog += @{
                Name = $user.Name
                Department = $userDept
                Status = "SKIPPED - Unknown Department"
                Email = $userMail
            }
            continue
        }

        # Execute the move
        Move-ADObject -Identity $user.ObjectGUID -TargetPath $targetOU -ErrorAction Stop
        
        $movedCount++
        $movementLog += @{
            Name = $user.Name
            Department = $userDept
            TargetOU = $targetOU
            Status = "MOVED"
            Email = $userMail
        }
        
        Write-Host "    ✓ Successfully moved to $userDept OU" -ForegroundColor Green
    }
    catch {
        Write-Host "[-] Error moving $($user.Name): $($_.Exception.Message)" -ForegroundColor Red
        $errorCount++
        $movementLog += @{
            Name = $user.Name
            Department = $user.Department
            Status = "ERROR: $($_.Exception.Message)"
            Email = $user.Mail
        }
    }
}

# Verification: Show distribution after move
Write-Host "`n=== VERIFICATION: User Distribution After Movement ===" -ForegroundColor Cyan

$verificationResults = @()
$totalVerified = 0

foreach ($dept in @('Administration', 'Finance', 'HR', 'IT', 'Sales', 'Operations', 'Marketing', 'Legal', 'Procurement', 'Support', 'Compliance', 'Security', 'Executive')) {
    try {
        $deptOU = $departmentMap[$dept]
        $userCount = (Get-ADUser -SearchBase $deptOU -SearchScope OneLevel -Filter * -ErrorAction SilentlyContinue).Count
        Write-Host "$dept OU: $userCount users" -ForegroundColor Cyan
        $totalVerified += $userCount
        
        $verificationResults += @{
            Department = $dept
            UserCount = $userCount
        }
    }
    catch {
        Write-Host "$dept OU: ERROR querying - $_" -ForegroundColor Red
    }
}

# Final summary
Write-Host "`n=== CORRECTION SUMMARY ===" -ForegroundColor Cyan
Write-Host "Users successfully moved: $movedCount" -ForegroundColor Green
Write-Host "Users skipped (no dept attribute): $skipCount" -ForegroundColor Yellow
Write-Host "Errors encountered: $errorCount" -ForegroundColor Red
Write-Host "Total users verified in departmental OUs: $totalVerified" -ForegroundColor Green

Write-Host "`n=== MOVEMENT LOG ===" -ForegroundColor Cyan
$movementLog | Format-Table -AutoSize

Write-Host "`n=== VERIFICATION RESULTS ===" -ForegroundColor Cyan
$verificationResults | Format-Table -AutoSize

Write-Host "`n=== CORRECTION COMPLETE ===" -ForegroundColor Green
Write-Host "Transcript saved to: C:\Logs\Fix-UserOUPlacement-*.txt" -ForegroundColor Cyan

Stop-Transcript