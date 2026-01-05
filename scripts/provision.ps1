param(
  [Parameter()]
  [switch] $UseDarkTheme, 

  [Parameter(Mandatory = $true)]
  [string] $Locale, 

  [Parameter(Mandatory = $true)]
  [string] $TimeZone, 

  [Parameter(Mandatory = $true)]
  [ValidateSet("virtualbox", "vmware")]
  [string] $Hypervisor
)

. "$PSScriptRoot/utilities.ps1"
Write-Log "Starting provisioning script"

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

Write-Log "Removing Search from Taskbar"
Set-RegistryKey -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' -Name SearchBoxTaskbarMode -Value 0 -Type DWord

Write-Log "Disabling Widgets on Taskbar"
Set-RegistryKey -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' -Name AllowNewsAndInterests -Value 0 -Type DWord

Write-Log 'Disabling Windows Defender'
if (Get-Command -ErrorAction SilentlyContinue Uninstall-WindowsFeature) {
    # for Windows Server.
    Get-WindowsFeature 'Windows-Defender*' | Uninstall-WindowsFeature
} else {
    # for Windows Client.
    Set-MpPreference `
        -DisableRealtimeMonitoring $true `
        -ExclusionPath @('C:\', 'D:\')
    Set-RegistryKey `
        -Path 'HKLM:/SOFTWARE/Policies/Microsoft/Windows Defender' `
        -Name DisableAntiSpyware `
        -Value 1 `
        -Type DWord
}

Write-Log "Applying some UI Tweaks"
## Originally from https://github.com/chef/bento/blob/main/packer_templates/scripts/windows/ui-tweaks.ps1
# Show file extensions
{Set-RegistryKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name HideFileExt -Type DWORD -Value 0}
# Show hidden files
{Set-RegistryKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name Hidden -Type DWORD -Value 1}
# Launch explorer to the PC not the user
{Set-RegistryKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name LaunchTo -Type DWORD -Value 1}
{Set-RegistryKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name FullPathAddress -Type DWORD -Value 1}
# Disable notification popups
{Set-RegistryKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name EnableBalloonTips -Type DWORD -Value 0}
# Disable error reporting popups
{Set-RegistryKey -Path 'HKCU:\Software\Microsoft\Windows\Windows Error Reporting' -Name DontShowUI -Type DWORD -Value 0}
# Disable prompting for a shutdown reason
{Set-RegistryKey -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Reliability' -Name ShutdownReasonOn -Type DWORD -Value 0}
# Set visual effects to best performance
{Set-RegistryKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' -Name VisualFXSetting -Type DWORD -Value 2}
# Dont use visual styles on windows and buttons
{Set-RegistryKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ThemeManager' -Name ThemeActive -Type DWORD -Value 1}
# Dont use common tasks in folders
{Set-RegistryKey  -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name WebView -Type DWORD -Value 0}
# Dont use drop shadows for icon labels on the desktop
{Set-RegistryKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name ListviewShadow -Type DWORD -Value 0}
# Dont use a background image for each folder type
{Set-RegistryKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name ListviewWatermark -Type DWORD -Value 0}
# Dont slide taskbar buttons
{Set-RegistryKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name TaskbarAnimations -Type DWORD -Value 0}
# Dont animate windows when minimizing and maximizing
{Set-RegistryKey -Path 'HKCU:\Control Panel\Desktop\WindowMetrics' -Name MinAnimate -Type STRING -Value 0}
# Dont show window contents while dragging
{Set-RegistryKey -Path 'HKCU:\Control Panel\Desktop' -Name DragFullWindows -Type STRING -Value 0}
# Dont Smooth edges of screen fonts
{Set-RegistryKey -Path 'HKCU:\Control Panel\Desktop' -Name FontSmoothing -Type STRING -Value 0}
# Dont show shadows under menus
{Set-RegistryKey -Path 'HKCU:\Control Panel\Desktop' -Name UserPreferencesMask -Type BINARY -Value (90,12,01,80)}

Write-Log 'Setting the vagrant account properties...'
# see the ADS_USER_FLAG_ENUM enumeration at https://msdn.microsoft.com/en-us/library/aa772300(v=vs.85).aspx
$AdsScript = 0x00001
$AdsAccountDisable = 0x00002
$AdsNormalAccount = 0x00200
$AdsDontExpirePassword = 0x10000
$account = [ADSI]'WinNT://./vagrant'
$account.Userflags = $AdsNormalAccount -bor $AdsDontExpirePassword
$account.SetInfo()

Write-Log 'Setting the Administrator account properties...'
$account = [ADSI]'WinNT://./Administrator'
$account.Userflags = $AdsNormalAccount -bor $AdsDontExpirePassword -bor $AdsAccountDisable
$account.SetInfo()

Write-Log 'Disabling Automatic Private IP Addressing (APIPA)...'
Set-RegistryKey `
  -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' `
  -Name IPAutoconfigurationEnabled `
  -Value 0 `
  -Type DWord

Write-Log 'Disabling IPv6...'
Set-RegistryKey `
  -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' `
  -Name DisabledComponents `
  -Value 0xff `
  -Type DWord

Write-Log 'Disabling the Windows Boot Manager menu...'
bcdedit /set '{bootmgr}' displaybootmenu no

Write-Log "Enable TLS 1.2."
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol `
  -bor [Net.SecurityProtocolType]::Tls12

if (![Environment]::Is64BitProcess) {
  throw 'this must run in a 64-bit PowerShell session'
}

if (!(New-Object System.Security.Principal.WindowsPrincipal(
      [Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
  throw 'this must run with Administrator privileges (e.g. in a elevated shell session)'
}

Add-Type -A System.IO.Compression.FileSystem

if ($Hypervisor -eq "virtualbox") {
  Write-Log "Installing VirtualBox Guest Additions"
  $guestAdditionsIsoPath = "$env:USERPROFILE\VBoxGuestAdditions.iso"
  $installed = $false 
  if (Test-Path $guestAdditionsIsoPath) {
    Write-Log "Found Guest Additions at $guestAdditionsIsoPath. Mounting as drive..."
    $mountResult = Mount-DiskImage -ImagePath $guestAdditionsIsoPath -PassThru
    $driveLetter = ($mountResult | Get-Volume).DriveLetter
    $guestAdditionsPath = "$($driveLetter):\VBoxWindowsAdditions.exe"
  }
  else {
    Write-Log "Guest Additions ISO not found at $guestAdditionsIsoPath. Searching removable drives..."
    $volumes = Get-Volume | Where-Object { $_.DriveType -ne 'Fixed' -and $_.DriveLetter }
    foreach ($volume in $volumes) {
      $driveLetter = $volume.DriveLetter
      $guestAdditionsPath = "$($driveLetter):\VBoxWindowsAdditions.exe"
      break;
    }
  }
  if (Test-Path $guestAdditionsPath) {
    Write-Log "Found Guest Additions at $guestAdditionsPath. Installing..."
    $certs = "${driveLetter}:\cert"
    Start-Process -FilePath "${certs}\VBoxCertUtil.exe" -ArgumentList "add-trusted-publisher ${certs}\vbox*.cer", "--root ${certs}\vbox*.cer"  -Wait
    Start-Process -FilePath $guestAdditionsPath -ArgumentList "/with_wddm", "/S" -Wait
    $installed = $true
  }
  
  if ($installed) {
    Write-Log "VirtualBox Guest Additions installed successfully."
  }
  else {
    Write-Log "VirtualBox Guest Additions not found on any removable drive." -Level "Error"
  }
}

elseif ($Hypervisor -eq "vmware") {
  Write-Log "Installing VMware Tools" ## TODO: Implement VMware Tools installation
}

Write-Log "Installing useful applications via Chocolatey"
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
  "Wireshark.exe"       = "C:\Program Files\Wireshark\Wireshark.exe"
  "Fiddler.exe"         = "C:\Program Files\Fiddler\Fiddler.exe"
  "clumsy.exe"          = "C:\Program Files\clumsy\clumsy.exe"
  "SoapUI.exe"          = "C:\Program Files\SmartBear\SoapUI\bin\SoapUI.exe"
  "LogExpert.exe"       = "C:\Program Files\LogExpert\LogExpert.exe"
  "WindowsTerminal.exe" = "C:\Program Files\WindowsApps\Microsoft.WindowsTerminal_*\wt.exe"
  "procexp64.exe"       = "C:\ProgramData\chocolatey\lib\sysinternals\tools\procexp64.exe"
  "Procmon64.exe"       = "C:\ProgramData\chocolatey\lib\sysinternals\tools\Procmon64.exe"
}

$appsToPin.GetEnumerator() | ForEach-Object {
  $resolvedPath = if ($_.Value -like "*`**") {
    Get-Item $_.Value -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
  }
  else {
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


