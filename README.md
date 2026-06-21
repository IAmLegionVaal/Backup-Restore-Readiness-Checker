# Backup Restore Readiness Checker

A PowerShell toolkit for Windows backup and restore readiness checks and selected guarded recovery actions.

## Diagnostic script

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Backup_Restore_Readiness_Checker.ps1
```

## Repair script

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Backup_Restore_Repair_Toolkit.ps1 -RestartVss -DryRun
```

Examples:

```powershell
.\Backup_Restore_Repair_Toolkit.ps1 -RestartVss
.\Backup_Restore_Repair_Toolkit.ps1 -StartFileHistoryService
.\Backup_Restore_Repair_Toolkit.ps1 -EnableSystemProtection C
.\Backup_Restore_Repair_Toolkit.ps1 -CreateRestorePoint 'Before Application Repair'
.\Backup_Restore_Repair_Toolkit.ps1 -RestoreSource D:\Backup\Folder -RestoreDestination C:\RestoreTest
```

## What the repair does

- Restarts Volume Shadow Copy services.
- Starts the File History service.
- Enables System Protection on one selected drive.
- Creates a named System Restore point.
- Restores one selected file or folder into a destination that does not already exist.
- Creates SHA-256 verification output for restored files.
- Captures service, volume and restore-point state before and after repair.
- Supports `-DryRun`, confirmation prompts, logs and clear exit codes.

## Safety

Restore destinations must be new, preventing accidental overwrite of existing data. The tool does not delete backups, modify backup schedules or initiate a reboot automatically.

## Author

Dewald Pretorius — L2 IT Support Engineer
