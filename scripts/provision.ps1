param(
  [Parameter()]
  [switch]
  $UseDarkTheme, 

  [Parameter(Mandatory = $true)]
  [string]
  $Locale, 

  [Parameter(Mandatory = $true)]
  [string]
  $TimeZone
)

. "$PSScriptRoot/utilities.ps1"
write-Log "Starting provisioning script"

$lightTheme = If ($UseDarkTheme) { "0" } else { "1" }
if ($UseDarkTheme) { 
  Write-Log "Configuring Dark Theme"
}
else { 
  Write-Log "Configuring Light Theme"
}

("AppsUseLightTheme", "SystemUsesLightTheme") | `
  Foreach-Object { Set-RegistryKey -Path 'Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name $_ -Value $lightTheme -Type String }

Write-Log "Configuring Locale and Timezone"
$cultureInfo = New-Object System.Globalization.CultureInfo($Locale)
$regionInfo = New-Object System.Globalization.RegionInfo($cultureInfo.LCID)

Set-WinSystemLocale -SystemLocale $cultureInfo.Name
Set-WinUserLanguageList -LanguageList $cultureInfo.Name -Force
Set-TimeZone -Id $TimeZone
Set-WinHomeLocation -GeoId $regionInfo.GeoId
Set-Culture -CultureInfo $cultureInfo.Name

Write-Log "Disable UAC Prompts"
Set-RegistryKey -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name ConsentPromptBehaviorAdmin -Value 0 -Type DWord

Write-Log "Disable Scheduled Maintenance"
Set-RegistryKey -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance' -Name MaintenanceDisabled -Value 1 -Type DWord

Write-Log "Enable Remote Desktop"
Set-RegistryKey -Path 'Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -Value 0 -Type DWord
New-NetFirewallRule -DisplayName "Packer - Allow Remote Desktop" -Direction Inbound -LocalPort 3389 -Protocol TCP -Action Allow 

("powershell-core", 
"dotnet-8.0-sdk", 
"wireshark",
"clumsy",
"fiddler",
"soapui",
"sysinternals",
"visualstudio2026-remotetools",
"logexpert") | ForEach-Object { 
  Write-Log "Installing $_"
  choco install -y $_
}

# Pin applications to taskbar
$appsToPin = @{
  "Wireshark.exe" = "C:\Program Files\Wireshark\Wireshark.exe"
  "Fiddler.exe" = "C:\Program Files\Fiddler\Fiddler.exe"
  "clumsy.exe" = "C:\Program Files\clumsy\clumsy.exe"
  "SoapUI.exe" = "C:\Program Files\SmartBear\SoapUI\bin\SoapUI.exe"
  "LogExpert.exe" = "C:\Program Files\LogExpert\LogExpert.exe"
  "WindowsTerminal.exe" = "C:\Program Files\WindowsApps\Microsoft.WindowsTerminal_*\wt.exe"
  "procexp64.exe" = "C:\ProgramData\chocolatey\lib\sysinternals\tools\procexp64.exe"
  "Procmon64.exe" = "C:\ProgramData\chocolatey\lib\sysinternals\tools\Procmon64.exe"
}

$appsToPin.GetEnumerator() | ForEach-Object {
  $resolvedPath = if ($_.Value -like "*`**") {
    Get-Item $_.Value -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
  } else {
    $_.Value
  }
  
  if ($resolvedPath -and (Test-Path $resolvedPath)) {
    Write-Log "Pinning $($_.Key) to taskbar"
    $shell = New-Object -ComObject Shell.Application
    $folder = Split-Path $resolvedPath
    $file = Split-Path $resolvedPath -Leaf
    $shellFolder = $shell.NameSpace($folder)
    $shellFile = $shellFolder.ParseName($file)
    if ($shellFile) {
      $shellFile.InvokeVerb("taskbarpin")
    }
  }
}


