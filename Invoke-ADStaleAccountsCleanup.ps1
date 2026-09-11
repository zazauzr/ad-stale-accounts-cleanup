<#
.SYNOPSIS
    Automates the identification and isolation of disabled Active Directory user accounts.
.DESCRIPTION
    Scans the domain for disabled user accounts, identifies accounts that are outside 
    the designated isolation Organization Unit (OU), logs the findings, and optionally 
    moves them to the isolation OU.
.PARAMETER TargetOU
    The Distinguished Name (DN) of the OU where disabled accounts should be moved.
.PARAMETER LogPath
    Path to the execution log file.
.PARAMETER WhatIf
    If specified, shows what would happen without making actual changes.
.EXAMPLE
    .\Invoke-ADStaleAccountsCleanup.ps1 -TargetOU "OU=StaleUsers,DC=example,DC=com" -WhatIf
#>

[CmdletBinding(SupportsShouldProcess = $true)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseBOMForUnicodeEncodedFile', '')]
param (
    [Parameter(Mandatory = $true)]
    [string]$TargetOU,

    [Parameter(Mandatory = $false)]
    [string]$LogPath = "C:\Logs\ADCleanup_$(Get-Date -Format 'yyyyMMdd').log"
)

begin {
    Write-Host "[*] Initializing Active Directory Cleanup Script..." -ForegroundColor Cyan
    
    # Ensure Active Directory Module is available
    if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
        throw "ActiveDirectory PowerShell module is required but not installed."
    }
    Import-Module ActiveDirectory

    # Create log directory if it doesn't exist
    $LogDir = Split-Path $LogPath
    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }

    "--- AD Cleanup Started at $(Get-Date) ---" | Out-File -FilePath $LogPath -Append
}

process {
    try {
        Write-Host "[*] Fetching all disabled user accounts..." -ForegroundColor Yellow
        $DisabledAccounts = Search-ADAccount -AccountDisabled -UsersOnly

        if ($null -eq $DisabledAccounts) {
            Write-Host "[+] No disabled accounts found in the domain." -ForegroundColor Green
            "No disabled accounts found." | Out-File -FilePath $LogPath -Append
            return
        }

        Write-Host "[*] Found $($DisabledAccounts.Count) disabled accounts total. Filtering for misplaced ones..." -ForegroundColor Yellow

        # Filter accounts that are NOT already in the Target Isolation OU
        # Escaping regex to prevent path mismatch
        $EscapedOU = [regex]::Escape($TargetOU)
        $MisplacedAccounts = $DisabledAccounts | Where-Object { $_.DistinguishedName -notmatch $EscapedOU }

        if ($null -eq $MisplacedAccounts -or $MisplacedAccounts.Count -eq 0) {
            Write-Host "[+] All disabled accounts are properly placed in the Target OU." -ForegroundColor Green
            "All accounts are in the correct OU." | Out-File -FilePath $LogPath -Append
            return
        }

        Write-Host "[!] Found $($MisplacedAccounts.Count) accounts outside of the target isolation OU." -ForegroundColor Red
        "Identified $($MisplacedAccounts.Count) misplaced accounts." | Out-File -FilePath $LogPath -Append

        foreach ($User in $MisplacedAccounts) {
            $LogMessage = "User: $($User.Name) ($($User.SamAccountName)) | Current DN: $($User.DistinguishedName)"
            Write-Host "[->] $LogMessage" -ForegroundColor LightGray
            $LogMessage | Out-File -FilePath $LogPath -Append

            # Execute Move
            try {
                # PowerShell automatically handles -WhatIf if the script is run with it
                Move-ADObject -Identity $User.DistinguishedName -TargetPath $TargetOU
                
                $SuccessMsg = "[SUCCESS] Moved $($User.SamAccountName) to $TargetOU"
                Write-Host "    $SuccessMsg" -ForegroundColor Green
                $SuccessMsg | Out-File -FilePath $LogPath -Append
            }
            catch {
                $ErrorMsg = "[ERROR] Failed to move $($User.SamAccountName). Reason: $($_.Exception.Message)"
                Write-Warning "    $ErrorMsg"
                $ErrorMsg | Out-File -FilePath $LogPath -Append
            }
        }
    }
    catch {
        Write-Error "Critical error during execution: $($_.Exception.Message)"
        "CRITICAL ERROR: $($_.Exception.Message)" | Out-File -FilePath $LogPath -Append
    }
}

end {
    Write-Host "[*] Script execution finished. Check logs at: $LogPath" -ForegroundColor Cyan
    "--- AD Cleanup Finished at $(Get-Date) ---`n" | Out-File -FilePath $LogPath -Append
}
