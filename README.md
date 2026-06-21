# Windows Performance Troubleshooting Toolkit

A PowerShell toolkit for Windows performance triage and selected guarded repairs.

## Diagnostic script

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Windows_Performance_Troubleshooting_Toolkit.ps1
```

## Repair script

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Windows_Performance_Repair_Toolkit.ps1 -ClearTemp -DryRun
```

Examples:

```powershell
.\Windows_Performance_Repair_Toolkit.ps1 -RestartService SysMain,WSearch
.\Windows_Performance_Repair_Toolkit.ps1 -StopProcessId 1234
.\Windows_Performance_Repair_Toolkit.ps1 -PowerPlan Balanced
.\Windows_Performance_Repair_Toolkit.ps1 -ClearTemp -RunSfc
```

## What the repair does

- Restarts explicitly selected Windows services.
- Stops one selected non-Session-0 process.
- Switches to the built-in Balanced or High Performance power plan.
- Removes stale files older than seven days from the current user’s temp directory.
- Runs System File Checker when selected.
- Captures before-and-after CPU, memory, uptime and top-process data.
- Supports `-DryRun`, confirmation prompts, logs and clear exit codes.

## Safety

Stopping a process can lose unsaved work. The tool refuses Session 0 process termination and does not change page-file, registry, driver or startup configuration automatically.

## Author

Dewald Pretorius — L2 IT Support Engineer
