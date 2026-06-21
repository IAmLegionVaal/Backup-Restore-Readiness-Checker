[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
 [switch]$RestartVss,
 [switch]$StartFileHistoryService,
 [ValidatePattern('^[A-Z]$')][string]$EnableSystemProtection,
 [string]$CreateRestorePoint,
 [string]$RestoreSource,
 [string]$RestoreDestination,
 [switch]$DryRun,[switch]$Yes,
 [string]$OutputPath=(Join-Path $env:ProgramData 'BackupRestoreRepair')
)
$ErrorActionPreference='Stop';$script:Failures=0;$script:Actions=0
$run=Join-Path $OutputPath (Get-Date -Format yyyyMMdd_HHmmss);New-Item -ItemType Directory $run -Force|Out-Null
$log=Join-Path $run 'repair.log';$before=Join-Path $run 'before.json';$after=Join-Path $run 'after.json'
function Log($m){"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m"|Tee-Object -FilePath $log -Append}
function Admin{$p=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent());$p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)}
function State{[pscustomobject]@{Collected=Get-Date;Services=Get-Service VSS,swprv,FhSvc,wbengine -ErrorAction SilentlyContinue|Select-Object Name,Status,StartType;Volumes=Get-Volume|Select-Object DriveLetter,FileSystem,HealthStatus,SizeRemaining,Size;RestorePoints=Get-ComputerRestorePoint -ErrorAction SilentlyContinue|Sort-Object SequenceNumber -Descending|Select-Object -First 10 SequenceNumber,Description,CreationTime}}
function Act($d,[scriptblock]$a){$script:Actions++;Log $d;if($DryRun){Log "DRY-RUN: $d";return};try{&$a;Log "SUCCESS: $d"}catch{$script:Failures++;Log "FAILED: $d - $($_.Exception.Message)"}}
State|ConvertTo-Json -Depth 6|Set-Content $before -Encoding UTF8
if(-not($RestartVss -or $StartFileHistoryService -or $EnableSystemProtection -or $CreateRestorePoint -or $RestoreSource)){Write-Error 'Choose at least one repair action.';exit 2}
if($RestoreSource){if(-not(Test-Path $RestoreSource)){Write-Error 'Restore source not found.';exit 2};if(-not $RestoreDestination){Write-Error '-RestoreDestination is required.';exit 2};if(Test-Path $RestoreDestination){Write-Error 'Restore destination must not already exist.';exit 20}}
if(-not $DryRun -and -not(Admin)){Write-Error 'Run from elevated PowerShell.';exit 4}
if(-not $Yes -and -not $DryRun){if((Read-Host 'Apply selected backup and restore actions? Type YES') -ne 'YES'){Log 'Cancelled.';exit 10}}
if($RestartVss){foreach($s in 'VSS','swprv'){Act "Restarting service $s" {Restart-Service $s -Force -ErrorAction Stop}}}
if($StartFileHistoryService){Act 'Starting File History service' {Set-Service FhSvc -StartupType Manual;Start-Service FhSvc}}
if($EnableSystemProtection){$drive="${EnableSystemProtection}:\";Act "Enabling system protection on $drive" {Enable-ComputerRestore -Drive $drive}}
if($CreateRestorePoint){Act "Creating restore point $CreateRestorePoint" {Checkpoint-Computer -Description $CreateRestorePoint -RestorePointType MODIFY_SETTINGS}}
if($RestoreSource){Act "Restoring $RestoreSource to $RestoreDestination" {Copy-Item -LiteralPath $RestoreSource -Destination $RestoreDestination -Recurse -Force -ErrorAction Stop;Get-ChildItem $RestoreDestination -Recurse -Force -ErrorAction SilentlyContinue|Get-FileHash -Algorithm SHA256|Export-Csv (Join-Path $run 'restored-files.csv') -NoTypeInformation}}
Start-Sleep 2;State|ConvertTo-Json -Depth 6|Set-Content $after -Encoding UTF8
if($script:Failures){Log "Completed with $script:Failures failure(s).";exit 20};Log "Repair completed. Actions: $script:Actions";exit 0
