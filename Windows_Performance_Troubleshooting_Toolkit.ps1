#requires -Version 5.1
<#
.SYNOPSIS
    Windows Performance Troubleshooting Toolkit.
.DESCRIPTION
    Read-only performance triage reporter for Windows support.
#>
[CmdletBinding()]
param([string]$OutputPath,[int]$Top=15)

$RunStamp = Get-Date -Format 'yyyyMMdd_HHmmss'
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Performance_Triage_Reports' }
New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
function Export-Data { param($Name,$Data) $Data | Export-Csv (Join-Path $OutputPath "$Name.csv") -NoTypeInformation -Encoding UTF8; $Data | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $OutputPath "$Name.json") -Encoding UTF8 }
$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem
$summary = [PSCustomObject]@{Computer=$env:COMPUTERNAME;OS=$os.Caption;Build=$os.BuildNumber;LastBoot=$os.LastBootUpTime;MemoryGB=[math]::Round($cs.TotalPhysicalMemory/1GB,2);Generated=Get-Date}
$cpu = Get-Process | Sort-Object CPU -Descending | Select-Object -First $Top Name,Id,CPU,PM,WS,StartTime -ErrorAction SilentlyContinue
$mem = Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First $Top Name,Id,CPU,@{n='WorkingSetMB';e={[math]::Round($_.WorkingSet64/1MB,2)}},StartTime -ErrorAction SilentlyContinue
$disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | Select-Object DeviceID,VolumeName,@{n='SizeGB';e={[math]::Round($_.Size/1GB,2)}},@{n='FreeGB';e={[math]::Round($_.FreeSpace/1GB,2)}},@{n='FreePercent';e={[math]::Round(($_.FreeSpace/$_.Size)*100,1)}}
$start = (Get-Date).AddHours(-24)
$events = Get-WinEvent -FilterHashtable @{LogName='System';Level=1,2,3;StartTime=$start} -ErrorAction SilentlyContinue | Select-Object -First 100 TimeCreated,Id,ProviderName,LevelDisplayName,Message
Export-Data -Name "system_summary_$RunStamp" -Data @($summary)
Export-Data -Name "top_cpu_processes_$RunStamp" -Data $cpu
Export-Data -Name "top_memory_processes_$RunStamp" -Data $mem
Export-Data -Name "disk_summary_$RunStamp" -Data $disks
Export-Data -Name "recent_system_events_$RunStamp" -Data $events
$html = "<h1>Windows Performance Triage - $env:COMPUTERNAME</h1><p>Generated $(Get-Date)</p><h2>Summary</h2>$(@($summary) | ConvertTo-Html -Fragment)<h2>Top CPU</h2>$($cpu | ConvertTo-Html -Fragment)<h2>Top Memory</h2>$($mem | ConvertTo-Html -Fragment)<h2>Disks</h2>$($disks | ConvertTo-Html -Fragment)"
$html | ConvertTo-Html -Title 'Performance Triage' | Set-Content (Join-Path $OutputPath "performance_triage_$RunStamp.html") -Encoding UTF8
$cpu | Format-Table -AutoSize
Write-Host "Reports saved to: $OutputPath" -ForegroundColor Green
Start-Process explorer.exe -ArgumentList "`"$OutputPath`"" -ErrorAction SilentlyContinue
