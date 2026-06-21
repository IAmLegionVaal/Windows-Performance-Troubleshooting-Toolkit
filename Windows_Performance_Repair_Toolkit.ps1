[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
 [string[]]$RestartService,
 [int]$StopProcessId,
 [ValidateSet('Balanced','HighPerformance')][string]$PowerPlan,
 [switch]$ClearTemp,
 [switch]$RunSfc,
 [switch]$DryRun,
 [switch]$Yes,
 [string]$OutputPath=(Join-Path $env:ProgramData 'WindowsPerformanceRepair')
)
$ErrorActionPreference='Stop'; $script:Failures=0; $script:Actions=0
$run=Join-Path $OutputPath (Get-Date -Format yyyyMMdd_HHmmss); New-Item -ItemType Directory $run -Force|Out-Null
$log=Join-Path $run 'repair.log'; $before=Join-Path $run 'before.json'; $after=Join-Path $run 'after.json'
function Log($m){"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m"|Tee-Object -FilePath $log -Append}
function Admin{$p=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent());$p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)}
function State{[pscustomobject]@{Collected=Get-Date;Uptime=((Get-Date)-(Get-CimInstance Win32_OperatingSystem).LastBootUpTime);Memory=(Get-CimInstance Win32_OperatingSystem|Select-Object TotalVisibleMemorySize,FreePhysicalMemory);CPU=(Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction SilentlyContinue).CounterSamples.CookedValue;TopCPU=Get-Process|Sort-Object CPU -Descending|Select-Object -First 10 Id,Name,CPU,WorkingSet64;TopMemory=Get-Process|Sort-Object WorkingSet64 -Descending|Select-Object -First 10 Id,Name,WorkingSet64}}
function Act($d,[scriptblock]$a){$script:Actions++;Log $d;if($DryRun){Log "DRY-RUN: $d";return};try{&$a;Log "SUCCESS: $d"}catch{$script:Failures++;Log "FAILED: $d - $($_.Exception.Message)"}}
State|ConvertTo-Json -Depth 5|Set-Content $before -Encoding UTF8
if(-not($RestartService -or $StopProcessId -or $PowerPlan -or $ClearTemp -or $RunSfc)){Write-Error 'Choose at least one repair action.';exit 2}
if(-not $DryRun -and -not(Admin)){Write-Error 'Run from elevated PowerShell.';exit 4}
if(-not $Yes -and -not $DryRun){if((Read-Host 'Apply selected performance repairs? Type YES') -ne 'YES'){Log 'Cancelled.';exit 10}}
foreach($s in @($RestartService)){Act "Restarting service $s" {Restart-Service -Name $s -Force -ErrorAction Stop}}
if($StopProcessId){$p=Get-Process -Id $StopProcessId -ErrorAction Stop;if($p.SessionId -eq 0){Write-Error 'Refusing to stop a Session 0 system process.';exit 2};Act "Stopping process $($p.Name) ($StopProcessId)" {Stop-Process -Id $StopProcessId -ErrorAction Stop}}
if($PowerPlan){$guid=if($PowerPlan -eq 'Balanced'){'381b4222-f694-41f0-9685-ff5bb260df2e'}else{'8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'};Act "Activating $PowerPlan power plan" {& powercfg.exe /setactive $guid;if($LASTEXITCODE -ne 0){throw "powercfg exited $LASTEXITCODE"}}}
if($ClearTemp){Act 'Removing stale current-user temp files older than seven days' {Get-ChildItem $env:TEMP -Force -ErrorAction SilentlyContinue|Where-Object LastWriteTime -lt (Get-Date).AddDays(-7)|Remove-Item -Recurse -Force -ErrorAction SilentlyContinue}}
if($RunSfc){Act 'Running System File Checker' {$p=Start-Process sfc.exe -ArgumentList '/scannow' -Wait -PassThru -NoNewWindow;if($p.ExitCode -notin 0,1){throw "SFC exited $($p.ExitCode)"}}}
Start-Sleep 2;State|ConvertTo-Json -Depth 5|Set-Content $after -Encoding UTF8
if($script:Failures){Log "Completed with $script:Failures failure(s).";exit 20};Log "Repair completed. Actions: $script:Actions";exit 0
