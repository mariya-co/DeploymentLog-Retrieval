# Script that remotely retrieves various log files related to OS/Application deployment and updates, filters them for errors and warnings, and saves them to a local directory.

# Get hostname of device
$computer = Read-Host "Enter hostname of device"

# Check to see if machine is online, and winrm can connect:
$pingCheck = Test-Connection $computer -Count 1 -Quiet
if (!$pingCheck) {
    Write-Host "Machine offline - please try again later"
    Start-Sleep -Seconds 5
    exit
}
# Testing to see if WinRM is configured and can connect to the remote machine
$testWSMAN = Test-WSMan -Computername $computer -Authentication default -ErrorAction SilentlyContinue
if (!$testWSMAN) {
    Write-Host "WSMan not configured/connected - please try reinstalling MECM client, otherwise the machine will have to be reimaged."
    Start-Sleep -Seconds 5
    exit
}

# Enumerate different log files, place their path into ordered hashtable, so that the copy-item goes through in the order specified.
$logFiles =  [ordered]@{
    cbs = "\\$computer\c$\windows\logs\cbs\cbs.log"
    ccmrepair = "\\$computer\c$\windows\ccm\logs\ccmrepair.log"
    ccmsetup = "\\$computer\c$\windows\ccmsetup\logs\ccmsetup.log"
    clientmsi = "\\$computer\c$\windows\ccmsetup\logs\client.msi.log"
    updatesdeployment = "\\$computer\c$\windows\ccm\logs\updatesdeployment.log"
    updateshandler = "\\$computer\c$\windows\ccm\logs\updateshandler.log"
    wuahandler = "\\$computer\c$\windows\ccm\logs\wuahandler.log"   
}

# Check on host machine whether temp exists, if not, create it, then regardless create a logs folder where the log files will go
 if (!(Test-Path -Path C:\temp)) {
            New-Item -Path C:\temp -ItemType Directory | Out-Null
        }
$logFolder = "C:\temp\$computer-logs"
if (!(Test-Path -Path $logFolder)) {
    New-Item -Path $logFolder -ItemType Directory | Out-Null
}

# Build out copy-item, using positions in the hashtable to fill in the file paths with a foreach loop that iterates through the keys of the hashtable.
foreach ($key in $logFiles.Keys) {
    $sourcePath = $logFiles[$key]
    $destinationPath = "C:\temp\$computer-logs\$computer-$key.log"
    try {
        Copy-Item -Path $sourcePath -Destination $destinationPath -ErrorAction Stop
        Write-Host "Successfully copied: $sourcePath"
    } catch {
        Write-Error $_.Exception
    }
}

# Run Get-windowsupdatelog on the device, then transfer the outputted file of this to the hostmachine
Invoke-Command -Computername $computer -Scriptblock {
    Get-Windowsupdatelog -Logpath "C:\temp\windowsupdate.log"
}

# Copy the windowsupdatelog to host device
Copy-Item -Path "\\$computer\c$\temp\windowsupdate.log" -Destination "$logFolder\$computer-windowsupdate.log"

# Set the filtered folder to store the filtered log files
$filteredFolder = Join-Path -Path $logFolder -ChildPath "filtered"

# Create the filtered folder if it doesn't exist
if (!(Test-Path -Path $filteredFolder)) {
    New-Item -Path $filteredFolder -ItemType Directory | Out-Null
}

# Loop through the original logFiles hashtable to apply filtering
foreach ($key in $logFiles.Keys) {
    $logFileName = "$computer-$key.log"
    $logFilePath = Join-Path -Path $logFolder -ChildPath $logFileName
    $filteredFilePath = Join-Path -Path $filteredFolder -ChildPath ("filtered-" + $logFileName)
        # Apply filtering based on log type
        if ($key -in @("ccmsetup", "updatesdeployment", "updateshandler", "wuahandler")) {
            Get-Content $logFilePath | Where-Object {
                $_ -match 'type="2"' -or $_ -match 'type="3"'
            } | Set-Content -Path $filteredFilePath
        }
    } 
# Seperate logic for windowsupdate.log as it's not originally contained in the hashtable, bit of a hack, but it works.
$windowsupdateLog = "$logFolder\$computer-windowsupdate.log"
$filteredWindowsUpdateLog = "$filteredFolder\filtered-$computer-windowsupdate.log"

if (Test-Path $windowsupdateLog) {
    Get-Content $windowsupdateLog | Where-Object {
        $_ -match '\*FAILED\*' -or $_ -match 'Error' -or $_ -match 'Exception' -or $_ -match '0x8024' -or $_ -match '0x8007'
    } | Set-Content -Path $filteredWindowsUpdateLog
    Write-Host "Filtered WindowsUpdate.log created at: $filteredWindowsUpdateLog" # Just to confirm that the filtered log writing is actually working properly.
} 


Write-Host -Foregroundcolor Green "Operation finished - please check $logFolder for bare log files, and $filteredFolder for logs that have been filtered down to show only errors and warnings."


 
