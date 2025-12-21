. "$PSScriptRoot/utilities.ps1"

Write-Log "Starting cleanup script"

("$env:localappdata\\temp\\*",
#"$env:windir\\logs",
"$env:windir\\panther",
"$env:programdata\\Microsoft\\Windows Defender\\Scans\\*") | ForEach-Object {
  Write-Log "Removing $_"
  try {
    Takeown /d Y /R /f $_ 2>&1 | Out-Null
    Icacls $_ /GRANT:r administrators:F /T /c /q 2>&1 | Out-Null
    Remove-Item $_ -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
  }
  catch {
    $global:error.RemoveAt(0) 
  }
}