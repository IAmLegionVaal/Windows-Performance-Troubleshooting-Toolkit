[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [switch]$Repair,
    [switch]$RestartExplorer,
    [switch]$ClearTemp,
    [switch]$ResetPerformanceCounters,
    [switch]$RunSystemRepair,
    [switch]$Force,
    [string]$OutputPath = "$env:USERPROFILE\Desktop\WindowsPerformanceRepair"
)

$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
$Log = Join-Path $OutputPath ("repair-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
function Write-Log { param([string]$Message) "$(Get-Date -Format s) $Message" | Tee-Object -FilePath $Log -Append }
function Test-Admin { $p=[Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent(); $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }
if (-not ($Repair -or $RestartExplorer -or $ClearTemp -or $ResetPerformanceCounters -or $RunSystemRepair)) { throw 'Choose at least one repair action.' }
if (-not (Test-Admin) -and ($ResetPerformanceCounters -or $RunSystemRepair)) { throw 'Run PowerShell as Administrator for system repairs.' }

Get-ComputerInfo | Select-Object WindowsProductName,WindowsVersion,OsBuildNumber,CsTotalPhysicalMemory | ConvertTo-Json | Set-Content (Join-Path $OutputPath 'before.json')

if ($Repair -or $RestartExplorer) {
    if ($PSCmdlet.ShouldProcess('Windows Explorer','Restart process')) {
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Process explorer.exe
        Write-Log 'Explorer restarted.'
    }
}
if ($Repair -or $ClearTemp) {
    $cutoff=(Get-Date).AddDays(-7)
    Get-ChildItem $env:TEMP -Force -ErrorAction SilentlyContinue | Where-Object LastWriteTime -lt $cutoff | ForEach-Object {
        if ($PSCmdlet.ShouldProcess($_.FullName,'Remove stale temporary item')) { Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }
    }
    Write-Log 'Stale temporary files processed.'
}
if ($Repair -or $ResetPerformanceCounters) {
    if ($PSCmdlet.ShouldProcess('Performance counter libraries','Rebuild')) {
        & lodctr.exe /R | Tee-Object -FilePath $Log -Append
        & winmgmt.exe /resyncperf | Tee-Object -FilePath $Log -Append
        Write-Log 'Performance counters rebuilt.'
    }
}
if ($Repair -or $RunSystemRepair) {
    if ($PSCmdlet.ShouldProcess('Windows component store','Repair with DISM and SFC')) {
        & dism.exe /Online /Cleanup-Image /RestoreHealth | Tee-Object -FilePath $Log -Append
        if ($LASTEXITCODE -ne 0) { throw "DISM failed with exit code $LASTEXITCODE" }
        & sfc.exe /scannow | Tee-Object -FilePath $Log -Append
        Write-Log 'System repair completed.'
    }
}
Get-Process | Sort-Object CPU -Descending | Select-Object -First 20 Name,Id,CPU,WorkingSet64 | Export-Csv (Join-Path $OutputPath 'after-processes.csv') -NoTypeInformation
Write-Log 'Repair workflow finished.'
