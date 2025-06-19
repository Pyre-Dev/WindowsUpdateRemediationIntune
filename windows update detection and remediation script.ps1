# Windows Update Remediation Script with CSV Logging and System File Repair

$logDir = "C:\ProgramData\CompanyName"
$logFile = "$logDir\FailedUpdates.csv"

# Ensure directory exists
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

# Collect update history
$Session = New-Object -ComObject "Microsoft.Update.Session"
$Searcher = $Session.CreateUpdateSearcher()
$HistoryCount = $Searcher.GetTotalHistoryCount()
$Updates = $Searcher.QueryHistory(0, $HistoryCount)

# Filter failed updates (ResultCode 4 = Failed)
$FailedUpdates = $Updates | Where-Object { $_.ResultCode -eq 4 }

# Log failures to CSV
if ($FailedUpdates.Count -gt 0) {
    $FailedUpdates | ForEach-Object {
        $entry = [PSCustomObject]@{
            ComputerName   = $env:COMPUTERNAME
            UserName       = $env:USERNAME
            Date           = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            Title          = $_.Title
            KBArticleIDs   = $_.UpdateIdentity.UpdateID
            ErrorCode      = $_.HResult
            Description    = $_.Description
        }
        $entry | Export-Csv -Path $logFile -Append -NoTypeInformation -Force
    }
}

# Remediation: Reset Windows Update components
Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
Stop-Service bits -Force -ErrorAction SilentlyContinue
Stop-Service cryptSvc -Force -ErrorAction SilentlyContinue
Stop-Service msiserver -Force -ErrorAction SilentlyContinue

Rename-Item -Path "C:\Windows\SoftwareDistribution" -NewName "SoftwareDistribution.old" -Force -ErrorAction SilentlyContinue
Rename-Item -Path "C:\Windows\System32\catroot2" -NewName "catroot2.old" -Force -ErrorAction SilentlyContinue

Start-Service wuauserv -ErrorAction SilentlyContinue
Start-Service bits -ErrorAction SilentlyContinue
Start-Service cryptSvc -ErrorAction SilentlyContinue
Start-Service msiserver -ErrorAction SilentlyContinue

# --- SYSTEM FILE HEALTH REPAIR ---

# Run System File Checker (SFC)
try {
    Write-Output "Running SFC scan..."
    Start-Process -FilePath "sfc.exe" -ArgumentList "/scannow" -Wait -NoNewWindow
    Write-Output "SFC scan completed."
} catch {
    Write-Output "SFC scan failed: $_"
}

# Run DISM health check and restore
try {
    Write-Output "Running DISM /scanhealth..."
    dism.exe /online /cleanup-image /scanhealth

    Write-Output "Running DISM /restorehealth..."
    dism.exe /online /cleanup-image /restorehealth
    Write-Output "DISM repair completed."
} catch {
    Write-Output "DISM failed: $_"
}

# Trigger update scan *after* repairs are complete
try {
    Write-Output "Re-initiating Windows Update scan after repairs..."
    Start-ScheduledTask -TaskName "Microsoft\Windows\WindowsUpdate\Scheduled Start"
    Write-Output "Update scan triggered successfully."
} catch {
    Write-Output "Failed to trigger update scan: $_"
}

Write-Output "Remediation script completed. Failures logged to CSV if present."
exit 0