# ==============================================================================
# Script Name: Fix-UserOUPlacement.ps1
# Description: Move users from Administration OU to correct departmental OUs
#              based on their Department attribute (populated during provisioning)
# Author: Phase 2.2 Corrective Action
# Date: June 19, 2026
# Status: CORRECTIVE - Addresses missing OU placement in initial provisioning
# ==============================================================================

$domain = "corp.infralab.local"
$domainDN = "DC=corp,DC=infralab,DC=local"

# Start transcript for audit trail
Start-Transcript -Path "C:\Logs\Fix-UserOUPlacement-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt" -Force

Write-Host "=== USER OU PLACEMENT CORRECTION ===" -ForegroundColor Cyan
Write-Host "Moving users from Administration OU to correct departmental OUs..." -ForegroundColor Cyan

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

# Get all users currently in Administration OU (not in sub-OUs like Groups, Devices, ServiceAccounts)
$administrationOU = "OU=Administration,$domainDN"
$usersInAdmin = Get-ADUser -Filter * -SearchBase $administrationOU -Properties Department | 
    Where-Object { $_.DistinguishedName -like "*OU=Administration,$domainDN" -and 
                   $_.DistinguishedName -notlike "*OU=Groups*" -and 
                   $_.DistinguishedName -notlike "*OU=Devices*" -and 
                   $_.DistinguishedName -notlike "*OU=ServiceAccounts*" }

Write-Host "Found $($usersInAdmin.Count) users to move" -ForegroundColor Yellow

$movedCount = 0
$errorCount = 0
$unmappedCount = 0

foreach ($user in $usersInAdmin) {
    try {
        $userDept = $user.Department
        
        # If user has no department attribute, put them in Administration Tier 0
        if ([string]::IsNullOrEmpty($userDept)) {
            $targetOU = $departmentMap['Administration']
            $unmappedCount++
            Write-Host "[!] $($user.Name) - No department attribute. Moving to Administration (Tier 0)." -ForegroundColor Yellow
        }
        elseif ($departmentMap.ContainsKey($userDept)) {
            $targetOU = $departmentMap[$userDept]
            Write-Host "[+] $($user.Name) - Department: $userDept → Moving to $($departmentMap.Keys | Where-Object { $departmentMap[$_] -eq $targetOU })" -ForegroundColor Green
        }
        else {
            Write-Host "[-] $($user.Name) - Unknown department: $userDept. Skipping." -ForegroundColor Red
            $errorCount++
            continue
        }

        # Move user to target OU
        Move-ADObject -Identity $user.ObjectGUID -TargetPath $targetOU -ErrorAction Stop
        $movedCount++
    }
    catch {
        Write-Host "[-] Error moving $($user.Name): $_" -ForegroundColor Red
        $errorCount++
    }
}

Write-Host "`n=== CORRECTION SUMMARY ===" -ForegroundColor Cyan
Write-Host "Users moved: $movedCount" -ForegroundColor Green
Write-Host "Errors: $errorCount" -ForegroundColor Yellow
Write-Host "Unmapped (moved to Tier 0): $unmappedCount" -ForegroundColor Yellow

# Verification: Show distribution after move
Write-Host "`n=== VERIFICATION: User Distribution After Move ===" -ForegroundColor Cyan

$allDepts = @('Administration', 'Finance', 'HR', 'IT', 'Sales', 'Operations', 'Marketing', 'Legal', 'Procurement', 'Support', 'Compliance', 'Security', 'Executive')

foreach ($dept in $allDepts) {
    $deptOU = $departmentMap[$dept]
    $userCount = (Get-ADUser -Filter * -SearchBase $deptOU).Count
    Write-Host "$dept OU: $userCount users" -ForegroundColor Cyan
}

Write-Host "`n=== CORRECTION COMPLETE ===" -ForegroundColor Green

Stop-Transcript
