# ==============================================================================
# Script Name: Create-TierStructure.ps1
# Description: Create Tier 0/1/2 admin structure with proper group assignments
#              for FGPP policy application
# Author: Phase 2.2 Corrective Action
# Date: June 19, 2026
# Status: CORRECTIVE - Establishes tiered admin model for FGPP (Phase 2.3A)
# ==============================================================================

$domain = "corp.infralab.local"
$domainDN = "DC=corp,DC=infralab,DC=local"

Start-Transcript -Path "C:\Logs\Create-TierStructure-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt" -Force

Write-Host "=== TIER STRUCTURE CREATION ===" -ForegroundColor Cyan

# =============================================================================
# STEP 1: Create Tier 0 OU
# =============================================================================

$tier0OUPath = "OU=Tier0-Admins,OU=Administration,$domainDN"
$tier0OUName = "Tier0-Admins"

try {
    $existingOU = Get-ADOrganizationalUnit -Filter "Name -eq '$tier0OUName'" -ErrorAction SilentlyContinue
    if (-not $existingOU) {
        New-ADOrganizationalUnit -Name $tier0OUName -Path "OU=Administration,$domainDN" -ErrorAction Stop
        Write-Host "[+] Created Tier 0 OU: $tier0OUPath" -ForegroundColor Green
    } else {
        Write-Host "[!] Tier 0 OU already exists" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "[-] Error creating Tier 0 OU: $_" -ForegroundColor Red
}

# =============================================================================
# STEP 2: Create Tier 0 Admin Accounts (3 dedicated forest admins)
# =============================================================================

Write-Host "`n=== Creating Tier 0 Admin Accounts ===" -ForegroundColor Cyan

$tier0Admins = @(
    @{
        Name = 'ForestAdmin-1'
        DisplayName = 'Forest Administrator 1'
        GivenName = 'Forest'
        Surname = 'Admin1'
        Title = 'Forest Administrator'
        Department = 'Administration'
    },
    @{
        Name = 'ServiceAdmin-1'
        DisplayName = 'Service Administrator'
        GivenName = 'Service'
        Surname = 'Admin'
        Title = 'Service Administrator'
        Department = 'Administration'
    },
    @{
        Name = 'BackupAdmin-1'
        DisplayName = 'Backup Administrator'
        GivenName = 'Backup'
        Surname = 'Admin'
        Title = 'Backup Administrator'
        Department = 'Administration'
    }
)

$tier0AdminCount = 0

foreach ($admin in $tier0Admins) {
    try {
        $existingUser = Get-ADUser -Filter "SAMAccountName -eq '$($admin.Name)'" -ErrorAction SilentlyContinue
        
        if (-not $existingUser) {
            # Generate complex password
            $password = ([char[]]([char]65..[char]90) + ([char[]]([char]97..[char]122)) + ([char[]]([char]48..[char]57)) + @('!', '@', '#', '$', '%', '^', '&', '*') | 
                        Sort-Object { Get-Random }) -join '' | 
                        Select-Object -First 16 | 
                        ForEach-Object { -join $_ }
            
            $secPassword = ConvertTo-SecureString -String $password -AsPlainText -Force
            
            New-ADUser -Name $admin.Name `
                -SAMAccountName $admin.Name `
                -UserPrincipalName "$($admin.Name)@$domain" `
                -DisplayName $admin.DisplayName `
                -GivenName $admin.GivenName `
                -Surname $admin.Surname `
                -Title $admin.Title `
                -Department $admin.Department `
                -Path $tier0OUPath `
                -AccountPassword $secPassword `
                -Enabled $true `
                -ChangePasswordAtLogon $true `
                -ErrorAction Stop
            
            Write-Host "[+] Created Tier 0 admin: $($admin.Name)" -ForegroundColor Green
            Write-Host "    Password: $password" -ForegroundColor Yellow
            Write-Host "    Must change at logon: Yes" -ForegroundColor Yellow
            $tier0AdminCount++
        } else {
            Write-Host "[!] Tier 0 admin already exists: $($admin.Name)" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "[-] Error creating Tier 0 admin $($admin.Name): $_" -ForegroundColor Red
    }
}

# =============================================================================
# STEP 3: Create Security Groups for Tier Assignment
# =============================================================================

Write-Host "`n=== Creating Security Groups ===" -ForegroundColor Cyan

$groupsOU = "OU=Groups,OU=Administration,$domainDN"
$groups = @(
    @{ Name = 'SG-Tier0-Admins'; Description = 'Tier 0 Forest Administrators - Highest Privilege' },
    @{ Name = 'SG-Tier1-Admins'; Description = 'Tier 1 Department Admins - Elevated Privilege' },
    @{ Name = 'SG-Tier2-Users'; Description = 'Tier 2 Standard Users - Standard Privilege' }
)

$createdGroups = @{}

foreach ($group in $groups) {
    try {
        $existingGroup = Get-ADGroup -Filter "Name -eq '$($group.Name)'" -ErrorAction SilentlyContinue
        
        if (-not $existingGroup) {
            New-ADGroup -Name $group.Name `
                -GroupCategory Security `
                -GroupScope Global `
                -Description $group.Description `
                -Path $groupsOU `
                -ErrorAction Stop
            
            Write-Host "[+] Created group: $($group.Name)" -ForegroundColor Green
            $createdGroups[$group.Name] = $true
        } else {
            Write-Host "[!] Group already exists: $($group.Name)" -ForegroundColor Yellow
            $createdGroups[$group.Name] = $true
        }
    }
    catch {
        Write-Host "[-] Error creating group $($group.Name): $_" -ForegroundColor Red
    }
}

# =============================================================================
# STEP 4: Assign Tier 0 Admins to SG-Tier0-Admins
# =============================================================================

Write-Host "`n=== Assigning Tier 0 Admins to Group ===" -ForegroundColor Cyan

foreach ($admin in $tier0Admins) {
    try {
        $user = Get-ADUser -Filter "SAMAccountName -eq '$($admin.Name)'" -ErrorAction SilentlyContinue
        
        if ($user) {
            $group = Get-ADGroup -Filter "Name -eq 'SG-Tier0-Admins'" -ErrorAction SilentlyContinue
            
            if ($group) {
                $isMember = Get-ADGroupMember -Identity $group -ErrorAction SilentlyContinue | 
                            Where-Object { $_.DistinguishedName -eq $user.DistinguishedName }
                
                if (-not $isMember) {
                    Add-ADGroupMember -Identity $group -Members $user -ErrorAction Stop
                    Write-Host "[+] Added $($admin.Name) to SG-Tier0-Admins" -ForegroundColor Green
                } else {
                    Write-Host "[!] $($admin.Name) already in SG-Tier0-Admins" -ForegroundColor Yellow
                }
            }
        }
    }
    catch {
        Write-Host "[-] Error assigning $($admin.Name) to Tier 0 group: $_" -ForegroundColor Red
    }
}

# =============================================================================
# STEP 5: Identify and Assign Tier 1 Admins (Users with "Manager" in Title)
# =============================================================================

Write-Host "`n=== Identifying Tier 1 Admins (Department Managers) ===" -ForegroundColor Cyan

$departments = @('Finance', 'HR', 'IT', 'Sales', 'Operations', 'Marketing', 'Legal', 'Procurement', 'Support', 'Compliance', 'Security', 'Executive')
$tier1AdminCount = 0

foreach ($dept in $departments) {
    try {
        # Find users in this department with "Manager" or "Lead" in Title
        $deptOU = "OU=$dept,OU=Departments,OU=Administration,$domainDN"
        
        $managers = Get-ADUser -Filter { Title -like "*Manager*" -or Title -like "*Lead*" -or Title -like "*Head*" } `
                   -SearchBase $deptOU `
                   -Properties Title `
                   -ErrorAction SilentlyContinue
        
        if ($managers) {
            # Take first manager/lead (one per department)
            $tier1Admin = $managers | Select-Object -First 1
            
            try {
                $tier1Group = Get-ADGroup -Filter "Name -eq 'SG-Tier1-Admins'" -ErrorAction SilentlyContinue
                
                if ($tier1Group) {
                    $isMember = Get-ADGroupMember -Identity $tier1Group -ErrorAction SilentlyContinue | 
                                Where-Object { $_.DistinguishedName -eq $tier1Admin.DistinguishedName }
                    
                    if (-not $isMember) {
                        Add-ADGroupMember -Identity $tier1Group -Members $tier1Admin -ErrorAction Stop
                        Write-Host "[+] $($dept): $($tier1Admin.Name) ($($tier1Admin.Title)) → SG-Tier1-Admins" -ForegroundColor Green
                        $tier1AdminCount++
                    } else {
                        Write-Host "[!] $($tier1Admin.Name) already in SG-Tier1-Admins" -ForegroundColor Yellow
                    }
                }
            }
            catch {
                Write-Host "[-] Error assigning $($tier1Admin.Name) to Tier 1: $_" -ForegroundColor Red
            }
        } else {
            Write-Host "[!] No manager/lead found in $dept department" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "[-] Error processing $dept department: $_" -ForegroundColor Red
    }
}

# =============================================================================
# STEP 6: Assign All Remaining Users to Tier 2
# =============================================================================

Write-Host "`n=== Assigning Tier 2 Standard Users to Group ===" -ForegroundColor Cyan

try {
    $tier2Group = Get-ADGroup -Filter "Name -eq 'SG-Tier2-Users'" -ErrorAction SilentlyContinue
    $tier0Group = Get-ADGroup -Filter "Name -eq 'SG-Tier0-Admins'" -ErrorAction SilentlyContinue
    $tier1Group = Get-ADGroup -Filter "Name -eq 'SG-Tier1-Admins'" -ErrorAction SilentlyContinue
    
    # Get all users in Departments OUs
    $allDeptUsers = Get-ADUser -Filter * -SearchBase "OU=Departments,OU=Administration,$domainDN" -ErrorAction SilentlyContinue
    
    $tier2AssignCount = 0
    
    foreach ($user in $allDeptUsers) {
        # Skip if already in Tier 0 or Tier 1
        $inTier0 = Get-ADGroupMember -Identity $tier0Group -ErrorAction SilentlyContinue | 
                   Where-Object { $_.DistinguishedName -eq $user.DistinguishedName }
        
        $inTier1 = Get-ADGroupMember -Identity $tier1Group -ErrorAction SilentlyContinue | 
                   Where-Object { $_.DistinguishedName -eq $user.DistinguishedName }
        
        if (-not $inTier0 -and -not $inTier1) {
            $inTier2 = Get-ADGroupMember -Identity $tier2Group -ErrorAction SilentlyContinue | 
                       Where-Object { $_.DistinguishedName -eq $user.DistinguishedName }
            
            if (-not $inTier2) {
                Add-ADGroupMember -Identity $tier2Group -Members $user -ErrorAction SilentlyContinue
                $tier2AssignCount++
            }
        }
    }
    
    Write-Host "[+] Assigned $tier2AssignCount users to SG-Tier2-Users" -ForegroundColor Green
}
catch {
    Write-Host "[-] Error assigning Tier 2 users: $_" -ForegroundColor Red
}

# =============================================================================
# STEP 7: Verification and Summary
# =============================================================================

Write-Host "`n=== TIER STRUCTURE VERIFICATION ===" -ForegroundColor Cyan

$tier0GroupMemberCount = (Get-ADGroupMember -Identity "SG-Tier0-Admins" -ErrorAction SilentlyContinue).Count
$tier1GroupMemberCount = (Get-ADGroupMember -Identity "SG-Tier1-Admins" -ErrorAction SilentlyContinue).Count
$tier2GroupMemberCount = (Get-ADGroupMember -Identity "SG-Tier2-Users" -ErrorAction SilentlyContinue).Count

Write-Host "Tier 0 (Forest Admins) - SG-Tier0-Admins: $tier0GroupMemberCount members" -ForegroundColor Green
Write-Host "Tier 1 (Department Admins) - SG-Tier1-Admins: $tier1GroupMemberCount members" -ForegroundColor Green
Write-Host "Tier 2 (Standard Users) - SG-Tier2-Users: $tier2GroupMemberCount members" -ForegroundColor Green
Write-Host "Total: $($tier0GroupMemberCount + $tier1GroupMemberCount + $tier2GroupMemberCount) users assigned to tier groups" -ForegroundColor Green

Write-Host "`n=== TIER STRUCTURE COMPLETE ===" -ForegroundColor Green

Stop-Transcript