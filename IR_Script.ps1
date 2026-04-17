# IR Data Collection Script
#
# Collects volatile data, then non-volatile.

$ErrorActionPreference = "Continue"
$ProgressPreference    = "SilentlyContinue"

$hostName = $env:COMPUTERNAME
$stamp    = Get-Date -Format "yyyyMMdd_HHmmss"
$out      = ".\IR_${hostName}_${stamp}.txt"

function Write-Section {
    param($title)
    $bar = "=" * 70
    Add-Content $out ""
    Add-Content $out $bar
    Add-Content $out " $title"
    Add-Content $out " $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Add-Content $out $bar
}

# log header
Set-Content $out "IR Collection Log"
Add-Content $out "Host       : $hostName"
Add-Content $out "User       : $env:USERDOMAIN\$env:USERNAME"
Add-Content $out "Started    : $(Get-Date)"
Add-Content $out "PowerShell : $($PSVersionTable.PSVersion)"
Add-Content $out "OS         : $([System.Environment]::OSVersion.VersionString)"

$start = Get-Date
Write-Host "IR collection -> $out"


# =============== VOLATILE ===============

Write-Section "1. System Date and Time"
"Local : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff')" | Add-Content $out
"UTC   : $((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss.fff'))" | Add-Content $out
Get-TimeZone | Out-String | Add-Content $out
Get-CimInstance Win32_OperatingSystem | Select LastBootUpTime, LocalDateTime | Out-String | Add-Content $out


Write-Section "2. Running Processes and Services"
"-- Processes --" | Add-Content $out
Get-CimInstance Win32_Process |
    Select ProcessId, ParentProcessId, Name, CommandLine, ExecutablePath, CreationDate,
        @{n="Owner";e={
            $o = Invoke-CimMethod -InputObject $_ -MethodName GetOwner -EA 0
            if ($o.User) { "$($o.Domain)\$($o.User)" } else { "" }
        }},
        WorkingSetSize, HandleCount, ThreadCount |
    Sort ProcessId | Format-Table -Auto | Out-String -Width 500 | Add-Content $out

"-- Services --" | Add-Content $out
Get-CimInstance Win32_Service |
    Select State, StartMode, Name, DisplayName, StartName, PathName, ProcessId |
    Sort State, Name | Format-Table -Auto | Out-String -Width 500 | Add-Content $out


Write-Section "3. Open and Listening Ports"
"-- TCP --" | Add-Content $out
Get-NetTCPConnection |
    Select LocalAddress, LocalPort, RemoteAddress, RemotePort, State, OwningProcess,
        @{n="Process";e={(Get-Process -Id $_.OwningProcess -EA 0).ProcessName}} |
    Sort State, LocalPort | Format-Table -Auto | Out-String -Width 500 | Add-Content $out

"-- UDP --" | Add-Content $out
Get-NetUDPEndpoint |
    Select LocalAddress, LocalPort, OwningProcess,
        @{n="Process";e={(Get-Process -Id $_.OwningProcess -EA 0).ProcessName}} |
    Sort LocalPort | Format-Table -Auto | Out-String -Width 500 | Add-Content $out


Write-Section "4. Routing Table"
"-- IPv4 --" | Add-Content $out
Get-NetRoute -AddressFamily IPv4 |
    Select DestinationPrefix, NextHop, RouteMetric, InterfaceAlias, Protocol |
    Format-Table -Auto | Out-String -Width 500 | Add-Content $out
"-- IPv6 --" | Add-Content $out
Get-NetRoute -AddressFamily IPv6 |
    Select DestinationPrefix, NextHop, RouteMetric, InterfaceAlias, Protocol |
    Format-Table -Auto | Out-String -Width 500 | Add-Content $out


Write-Section "5. ARP Cache"
Get-NetNeighbor -AddressFamily IPv4 -EA 0 |
    Select InterfaceAlias, IPAddress, LinkLayerAddress, State |
    Sort InterfaceAlias, IPAddress | Format-Table -Auto | Out-String -Width 500 | Add-Content $out

"-- IPv6 neighbors --" | Add-Content $out
Get-NetNeighbor -AddressFamily IPv6 -EA 0 |
    Select InterfaceAlias, IPAddress, LinkLayerAddress, State |
    Sort InterfaceAlias, IPAddress | Format-Table -Auto | Out-String -Width 500 | Add-Content $out


Write-Section "6. NetBIOS"
Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "IPEnabled=TRUE" |
    Select Description, IPAddress, MACAddress, TcpipNetbiosOptions,
        WINSPrimaryServer, WINSSecondaryServer |
    Format-List | Out-String -Width 500 | Add-Content $out

# TcpipNetbiosOptions: 0=use DHCP, 1=enabled, 2=disabled

"-- SMB Sessions --" | Add-Content $out
Get-SmbSession -EA 0 | Format-Table -Auto | Out-String -Width 500 | Add-Content $out
"-- SMB Connections --" | Add-Content $out
Get-SmbConnection -EA 0 | Format-Table -Auto | Out-String -Width 500 | Add-Content $out


Write-Section "7. Open Files and Handles"
"-- SMB Open Files --" | Add-Content $out
Get-SmbOpenFile -EA 0 | Format-Table -Auto | Out-String -Width 500 | Add-Content $out

"-- Top 40 processes by handle count --" | Add-Content $out
Get-Process | Sort Handles -Desc | Select -First 40 Id, ProcessName, Handles |
    Format-Table -Auto | Out-String -Width 500 | Add-Content $out


Write-Section "8. DNS Cache"
Get-DnsClientCache |
    Select Entry, Name, RecordName, RecordType, Status, TimeToLive, Data |
    Sort Entry | Format-Table -Auto | Out-String -Width 500 | Add-Content $out


Write-Section "9. Memory"
$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem
"Total physical : {0:N0} MB" -f ($cs.TotalPhysicalMemory / 1MB)    | Add-Content $out
"Free physical  : {0:N0} MB" -f ($os.FreePhysicalMemory   / 1KB)   | Add-Content $out
"Total virtual  : {0:N0} MB" -f ($os.TotalVirtualMemorySize / 1KB) | Add-Content $out
"Free virtual   : {0:N0} MB" -f ($os.FreeVirtualMemory    / 1KB)   | Add-Content $out

"-- Installed DIMMs --" | Add-Content $out
Get-CimInstance Win32_PhysicalMemory |
    Select BankLabel, DeviceLocator, Capacity, Speed, Manufacturer, PartNumber, SerialNumber |
    Format-Table -Auto | Out-String -Width 500 | Add-Content $out

"-- Top 20 processes by working set --" | Add-Content $out
Get-Process | Sort WorkingSet64 -Desc | Select -First 20 Id, ProcessName,
        @{n="WS_MB";  e={[int]($_.WorkingSet64/1MB)}},
        @{n="Priv_MB";e={[int]($_.PrivateMemorySize64/1MB)}},
        @{n="VM_MB";  e={[int]($_.VirtualMemorySize64/1MB)}}, Path |
    Format-Table -Auto | Out-String -Width 500 | Add-Content $out

# credential + key extraction / resident PEs / strings


# =============== NON-VOLATILE ===============

Write-Section "10. Interface IP Addresses"
Get-NetAdapter |
    Select Name, InterfaceDescription, Status, MacAddress, LinkSpeed |
    Format-Table -Auto | Out-String -Width 500 | Add-Content $out

Get-NetIPAddress |
    Select InterfaceAlias, IPAddress, PrefixLength, AddressFamily, Type, AddressState |
    Sort InterfaceAlias, AddressFamily | Format-Table -Auto | Out-String -Width 500 | Add-Content $out

Get-NetIPConfiguration -Detailed | Out-String -Width 500 | Add-Content $out


Write-Section "11. Users Logged In / On System"
"Console user : $((Get-CimInstance Win32_ComputerSystem).UserName)" | Add-Content $out

"-- Logon Sessions --" | Add-Content $out
Get-CimInstance Win32_LogonSession |
    Select LogonId, LogonType,
        @{n="Type";e={
            switch ($_.LogonType) {
                2  {"Interactive"}
                3  {"Network"}
                4  {"Batch"}
                5  {"Service"}
                7  {"Unlock"}
                8  {"NetCleartext"}
                9  {"NewCreds"}
                10 {"RDP"}
                11 {"CachedInteractive"}
                default {"$($_.LogonType)"}
            }}},
        StartTime, AuthenticationPackage |
    Sort StartTime -Desc | Format-Table -Auto | Out-String -Width 500 | Add-Content $out

"-- Active Logons --" | Add-Content $out
Get-CimInstance Win32_LoggedOnUser | ForEach-Object {
    [PSCustomObject]@{
        Account = "$($_.Antecedent.Domain)\$($_.Antecedent.Name)"
        LogonId = $_.Dependent.LogonId
    }
} | Sort Account -Unique | Format-Table -Auto | Out-String -Width 500 | Add-Content $out

"-- Local Users --" | Add-Content $out
Get-LocalUser -EA 0 |
    Select Name, Enabled, LastLogon, PasswordLastSet, PasswordRequired, SID, Description |
    Format-Table -Auto | Out-String -Width 500 | Add-Content $out

"-- Local Administrators --" | Add-Content $out
Get-LocalGroupMember -Group Administrators -EA 0 |
    Format-Table -Auto | Out-String -Width 500 | Add-Content $out


Write-Section "12. Registry"
$regKeys = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunServices",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon",
    "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Image File Execution Options",
    "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager",
    "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa",
    "HKLM:\SYSTEM\MountedDevices"
)

foreach ($k in $regKeys) {
    "--- $k ---" | Add-Content $out
    if (Test-Path $k) {
        $item = Get-Item $k -EA 0
        if ($item.Property.Count -eq 0) {
            "  (no values)" | Add-Content $out
        } else {
            foreach ($p in $item.Property) {
                $v = (Get-ItemProperty $k -Name $p -EA 0).$p
                "  $p = $v" | Add-Content $out
            }
        }
    } else {
        "  (key not present)" | Add-Content $out
    }
}

# USB storage history
"-- USBSTOR --" | Add-Content $out
if (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR") {
    Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR" -EA 0 | ForEach-Object {
        $vendor = $_.PSChildName
        Get-ChildItem $_.PSPath -EA 0 | ForEach-Object {
            $fn = (Get-ItemProperty $_.PSPath -EA 0).FriendlyName
            "  $vendor | $($_.PSChildName) | $fn" | Add-Content $out
        }
    }
}


Write-Section "13. Event Logs"
Get-WinEvent -ListLog * -EA 0 | Where { $_.RecordCount -gt 0 } |
    Sort RecordCount -Desc | Select -First 30 LogName, RecordCount, FileSize, LogFilePath |
    Format-Table -Auto | Out-String -Width 500 | Add-Content $out

"-- System log: last 30 errors/warnings --" | Add-Content $out
Get-WinEvent -FilterHashtable @{LogName="System"; Level=1,2,3} -MaxEvents 30 -EA 0 |
    Select TimeCreated, LevelDisplayName, Id, ProviderName, Message |
    Format-List | Out-String | Add-Content $out

# 4624 = success, 4625 = fail, 4634 = logoff, 4672 = special privs
"-- Security log: last 20 logon events --" | Add-Content $out
Get-WinEvent -FilterHashtable @{LogName="Security"; Id=4624,4625,4634,4672} -MaxEvents 20 -EA 0 |
    Select TimeCreated, Id,
        @{n="User";e={ try { $_.Properties[5].Value } catch { "" } }} |
    Format-Table -Auto | Out-String -Width 500 | Add-Content $out


Write-Section "14. Prefetch"
$pf = "$env:SystemRoot\Prefetch"
if (Test-Path $pf) {
    Get-ChildItem $pf -Filter *.pf -Force -EA 0 |
        Select Name, Length, CreationTimeUtc, LastWriteTimeUtc, LastAccessTimeUtc |
        Sort LastWriteTimeUtc -Desc |
        Format-Table -Auto | Out-String -Width 500 | Add-Content $out
} else {
    "Prefetch directory not found" | Add-Content $out
}


Write-Section "15. Directory Listings"
#access NFS
$paths = @(
    "$env:SystemRoot\System32",
    "$env:SystemRoot\Tasks",
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
    "$env:USERPROFILE\Downloads",
    "$env:USERPROFILE\Desktop",
    "$env:TEMP"
)
foreach ($p in $paths) {
    "--- $p ---" | Add-Content $out
    if (Test-Path $p) {
        Get-ChildItem $p -Force -EA 0 | Sort LastWriteTime -Desc |
            Select -First 30 Mode, Name, Length, CreationTimeUtc, LastWriteTimeUtc, LastAccessTimeUtc |
            Format-Table -Auto | Out-String -Width 500 | Add-Content $out
    } else {
        "(not present)" | Add-Content $out
    }
}


Write-Section "16. Pagefile and Hibernation"
Get-CimInstance Win32_PageFileSetting -EA 0 | Format-List | Out-String | Add-Content $out
Get-CimInstance Win32_PageFileUsage   -EA 0 | Format-List | Out-String | Add-Content $out

foreach ($f in @("C:\pagefile.sys","C:\swapfile.sys","C:\hiberfil.sys")) {
    if (Test-Path $f) {
        Get-Item $f -Force -EA 0 |
            Select FullName, Length, CreationTimeUtc, LastWriteTimeUtc |
            Format-List | Out-String | Add-Content $out
    } else {
        "$f : not present" | Add-Content $out
    }
}


Write-Section "17. System Information"
Get-CimInstance Win32_OperatingSystem |
    Select Caption, Version, BuildNumber, OSArchitecture, InstallDate,
           LastBootUpTime, RegisteredUser, Organization |
    Format-List | Out-String | Add-Content $out

Get-CimInstance Win32_ComputerSystem |
    Select Name, Domain, Workgroup, Manufacturer, Model, SystemType,
           NumberOfLogicalProcessors, TotalPhysicalMemory, UserName |
    Format-List | Out-String | Add-Content $out

Get-CimInstance Win32_BIOS |
    Select Manufacturer, Name, Version, SerialNumber, ReleaseDate, SMBIOSBIOSVersion |
    Format-List | Out-String | Add-Content $out

Get-CimInstance Win32_Processor |
    Select Name, Manufacturer, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed |
    Format-List | Out-String | Add-Content $out

"-- Hotfixes --" | Add-Content $out
Get-HotFix -EA 0 | Sort InstalledOn -Desc |
    Select HotFixID, Description, InstalledBy, InstalledOn |
    Format-Table -Auto | Out-String -Width 500 | Add-Content $out

"-- Environment --" | Add-Content $out
Get-ChildItem Env: | Sort Name | Format-Table -Auto | Out-String -Width 500 | Add-Content $out


Write-Section "18. Mounted Devices"
Get-PSDrive        | Format-Table -Auto | Out-String -Width 500 | Add-Content $out
Get-Disk -EA 0     | Format-Table -Auto | Out-String -Width 500 | Add-Content $out
Get-Partition -EA 0| Format-Table -Auto | Out-String -Width 500 | Add-Content $out
Get-Volume -EA 0   | Format-Table -Auto | Out-String -Width 500 | Add-Content $out

Get-CimInstance Win32_LogicalDisk |
    Select DeviceID, DriveType, VolumeName,
        @{n="Size_GB";e={[math]::Round($_.Size/1GB,2)}},
        @{n="Free_GB";e={[math]::Round($_.FreeSpace/1GB,2)}},
        FileSystem, VolumeSerialNumber |
    Format-Table -Auto | Out-String -Width 500 | Add-Content $out


Write-Section "19. Browser Cache"
$browsers = @(
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default",
    "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default",
    "$env:APPDATA\Mozilla\Firefox\Profiles"
)
foreach ($b in $browsers) {
    "--- $b ---" | Add-Content $out
    if (Test-Path $b) {
        Get-ChildItem $b -Force -EA 0 |
            Where { $_.Name -match "^(Cache|Code Cache|History|Cookies|Login Data|Web Data|Bookmarks|Top Sites|places\.sqlite|cookies\.sqlite|cache2)" } |
            Select FullName, Length, LastWriteTimeUtc |
            Format-Table -Auto | Out-String -Width 500 | Add-Content $out
    } else {
        "(not present)" | Add-Content $out
    }
}


Write-Section "20. Scheduled Tasks"
Get-ScheduledTask | ForEach-Object {
    $info = $_ | Get-ScheduledTaskInfo -EA 0
    [PSCustomObject]@{
        Path       = $_.TaskPath
        Name       = $_.TaskName
        State      = $_.State
        RunAs      = $_.Principal.UserId
        Actions    = ($_.Actions | ForEach-Object { "$($_.Execute) $($_.Arguments)".Trim() }) -join " | "
        LastRun    = $info.LastRunTime
        LastResult = $info.LastTaskResult
        NextRun    = $info.NextRunTime
    }
} | Sort Path, Name | Format-Table -Auto | Out-String -Width 500 | Add-Content $out


Write-Section "21. Installed Drivers"
Get-CimInstance Win32_PnPSignedDriver | Where { $_.DeviceName } |
    Select DeviceName, Manufacturer, DriverVersion, DriverDate, Signer, InfName |
    Sort DeviceName | Format-Table -Auto | Out-String -Width 500 | Add-Content $out

"-- System drivers --" | Add-Content $out
Get-CimInstance Win32_SystemDriver |
    Select Name, DisplayName, State, StartMode, PathName |
    Sort Name | Format-Table -Auto | Out-String -Width 500 | Add-Content $out



# =============== DONE ===============
$end = Get-Date
Add-Content $out ""
Add-Content $out ("=" * 70)
Add-Content $out "Finished : $end"
Add-Content $out "Duration : $($end - $start)"
Add-Content $out ("=" * 70)

# hash the output for chain of custody
$hash = Get-FileHash $out -Algorithm SHA256
"$($hash.Hash)  $([System.IO.Path]::GetFileName($out))" | Set-Content "$out.sha256"

Write-Host ""
Write-Host "Done. Output file: $out"
Write-Host "SHA256         : $($hash.Hash)"
Write-Host "Hash file      : $out.sha256"
Write-Host "Duration       : $($end - $start)"