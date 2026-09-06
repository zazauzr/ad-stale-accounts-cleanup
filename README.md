# Active Directory Stale Accounts Auditor & Isolation Tool

A production-ready PowerShell automation tool designed to identify disabled Active Directory (AD) user accounts, detect compliance drift (accounts left in production OUs), and automatically consolidate them into a secure, isolated Organization Unit (OU) pending deletion.

---

## 💡 Business Value & Problem Statement

### The Problem
In enterprise Windows environments, when employees leave the company, their user accounts are typically disabled by the Helpdesk. However, system administrators often forget to move these accounts out of production Organizational Units (OUs). 

Leaving disabled accounts scattered across the Active Directory structure causes:
1. **Security Compliance Drift:** Leftover accounts clutter access groups and obscure security audits.
2. **Operational Inefficiency:** Messy AD structure slows down GPO processing analysis and identity management automation.
3. **Lack of Lifecycle Control:** IT management cannot easily purge old data if expired accounts are mixed with active ones.

### The Solution
This tool automates the **"Discover & Isolate"** phase of the IT lifecycle. It crawls the entire domain hierarchy, compares the current location of disabled accounts against the designated "Stale/Pending Deletion" OU, generates an audit log, and safely migrates the non-compliant objects.

---

## 🛠️ Tech Stack & Prerequisites

* **Language:** PowerShell 5.1+ / Core 7.x
* **Modules:** `ActiveDirectory` (Included in RSAT - Remote Server Administration Tools)
* **Target OS:** Windows Server 2016 / 2019 / 2022 (Domain Controller environment)
* **Privileges:** Enterprise Admin / Domain Admin or delegated permissions to move objects between OUs.

---

## 📐 Script Architecture

```text
[Active Directory Domain]
       │
       ├──► Scans ALL User Accounts 
       │       │
       │       └───► Filter: AccountDisabled = True
       │
       ├──► Evaluates DistinguishedName (DN)
       │       │
       │       ├───► If NOT inside "Target Isolation OU" ──► Log Incident
       │       │                                                │
       │       └───► (Optional execution) ──────────────────────┴──► Move-ADObject to Isolation OU
```

---

## 🚀 Deployment & Usage Guide

### 1. Verification & Dry Run (Safe Mode)
Always test script behavior using the built-in `-WhatIf` safety flag. This ensures no actual changes are written to your Domain Controller database.

```powershell
# Define your organization's isolation OU path
$TargetOU = "OU=Pending Deletion,OU=UBA,DC=example,DC=com"

# Execute audit without moving objects
.\Invoke-ADStaleAccountsCleanup.ps1 -TargetOU $TargetOU -WhatIf
```

### 2. Production Execution
To perform the live migration of misplaced disabled users, run the script without the `-WhatIf` switch:

```powershell
.\Invoke-ADStaleAccountsCleanup.ps1 -TargetOU "OU=Pending Deletion,OU=UBA,DC=example,DC=com" -LogPath "C:\Logs\AD_Prod_Cleanup.log"
```

---

## 📊 Healthcheck & Verification

Upon successful execution, the script generates structural console output and logs actions into a persistent text file.

### Expected Console Output:
```ansi
[*] Initializing Active Directory Cleanup Script...
[*] Fetching all disabled user accounts...
[*] Found 14 disabled accounts total. Filtering for misplaced ones...
[!] Found 2 accounts outside of the target isolation OU.
[→] User: John Doe (j.doe) | Current DN: CN=John Doe,OU=Chelyabinsk,OU=UBA,DC=example,DC=com
    [SUCCESS] Moved j.doe to OU=Pending Deletion,OU=UBA,DC=example,DC=com
[*] Script execution finished. Check logs at: C:\Logs\ADCleanup_20260906.log
```

### Log File Structure Verification (`C:\Logs\ADCleanup_YYYYMMDD.log`):
```text
--- AD Cleanup Started at 09/06/2026 12:00:00 ---
Identified 2 misplaced accounts.
User: John Doe (j.doe) | Current DN: CN=John Doe,OU=Chelyabinsk,OU=UBA,DC=example,DC=com
[SUCCESS] Moved j.doe to OU=Pending Deletion,OU=UBA,DC=example,DC=com
--- AD Cleanup Finished at 09/06/2026 12:00:02 ---
```
