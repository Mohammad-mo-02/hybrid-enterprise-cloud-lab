# ==============================================================================
# Script Name: Provision-Infrastructure-Objects.ps1
# Description: Populates Security Groups and Computer Objects for Task 2.2B
# Usage: Run on WS2022-DC01 as Administrator
# ==============================================================================

$domain = "DC=corp,DC=infralab,DC=local"
$groupsOU = "OU=Groups,OU=Administration,$domain"
$devicesOU = "OU=Devices,OU=Administration,$domain"

Write-Host "--- Initializing Infrastructure Object Provisioning ---" -ForegroundColor Cyan

# 1. Create Role-Based Security Groups
try {
    New-ADGroup -Name "SG-Finance-Staff" -GroupCategory Security -GroupScope Global -Path $groupsOU -ErrorAction SilentlyContinue
    New-ADGroup -Name "SG-IT-Admins" -GroupCategory Security -GroupScope Global -Path $groupsOU -ErrorAction SilentlyContinue
    Write-Host "[+] Security Groups created successfully." -ForegroundColor Green
}
catch {
    Write-Warning "Could not create groups (they may already exist)."
}

# 2. Create Enterprise Device Objects
try {
    New-ADComputer -Name "WKS-Finance-001" -Path $devicesOU -ErrorAction SilentlyContinue
    New-ADComputer -Name "SRV-FileShare-01" -Path $devicesOU -ErrorAction SilentlyContinue
    Write-Host "[+] Computer objects created successfully." -ForegroundColor Green
}
catch {
    Write-Warning "Could not create computer objects (they may already exist)."
}

Write-Host "--- Task 2.2B Infrastructure Objects Provisioned ---" -ForegroundColor Cyan