#requires -Version 5.1
<#
.SYNOPSIS
    Backup Restore Readiness Checker.
.DESCRIPTION
    Read-only backup and restore readiness context reporter for Windows support.
#>
[CmdletBinding()]
param([string]$OutputPath,[int]$Hours=168)

$RunStamp = Get-Date -Format 'yyyyMMdd_HHmmss'
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Backup_Restore_Readiness_Reports' }
New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
function New-Check { param($Category,$Name,$Status,$Value,$Recommendation) [PSCustomObject]@{Category=$Category;Name=$Name;Status=$Status;Value=$Value;Recommendation=$Recommendation} }
$checks=@()
$volumes=Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | Select-Object DeviceID,VolumeName,FileSystem,@{n='SizeGB';e={[math]::Round($_.Size/1GB,2)}},@{n='FreeGB';e={[math]::Round($_.FreeSpace/1GB,2)}}
$volumes | Export-Csv (Join-Path $OutputPath "volumes_$RunStamp.csv") -NoTypeInformation -Encoding UTF8
foreach($v in $volumes){ $checks += New-Check 'Volumes' $v.DeviceID ($(if($v.FreeGB -lt 10){'Warning'}else{'OK'})) "Free=$($v.FreeGB)GB; Size=$($v.SizeGB)GB" 'Low free space can affect backup or restore activity.' }
foreach($name in @('VSS','SDRSVC','wbengine')){ $svc=Get-Service $name -ErrorAction SilentlyContinue; if($svc){$checks += New-Check 'Services' $svc.DisplayName 'Info' "Status=$($svc.Status); StartType=$($svc.StartType)" 'Review backup-related service context.'} }
$start=(Get-Date).AddHours(-1*$Hours)
$events=Get-WinEvent -FilterHashtable @{LogName='Application';StartTime=$start;Level=1,2,3} -ErrorAction SilentlyContinue | Where-Object {$_.ProviderName -match 'VSS|Backup|Windows Backup'} | Select-Object -First 100 TimeCreated,Id,ProviderName,LevelDisplayName,Message
$events | Export-Csv (Join-Path $OutputPath "backup_related_events_$RunStamp.csv") -NoTypeInformation -Encoding UTF8
$checks += New-Check 'Events' 'Backup-related warning/error events' ($(if(@($events).Count -gt 0){'Info'}else{'OK'})) (@($events).Count) 'Review exported event details when backup issues are reported.'
$checks | Export-Csv (Join-Path $OutputPath "backup_restore_readiness_$RunStamp.csv") -NoTypeInformation -Encoding UTF8
$checks | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $OutputPath "backup_restore_readiness_$RunStamp.json") -Encoding UTF8
$checks | ConvertTo-Html -Title 'Backup Restore Readiness' -PreContent "<h1>Backup Restore Readiness - $env:COMPUTERNAME</h1><p>Generated $(Get-Date)</p>" | Set-Content (Join-Path $OutputPath "backup_restore_readiness_$RunStamp.html") -Encoding UTF8
$checks | Format-Table -AutoSize -Wrap
Write-Host "Reports saved to: $OutputPath" -ForegroundColor Green
Start-Process explorer.exe -ArgumentList "`"$OutputPath`"" -ErrorAction SilentlyContinue
