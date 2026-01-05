. "$PSScriptRoot/utilities.ps1"

Write-Log "Starting debloat script"

# Debloat windows, copied from https://github.com/memstechtips/UnattendedWinstall 

Write-Log "Setting up AppX compatibility aliases for this session..."
try {
    Set-Alias Get-AppPackageAutoUpdateSettings Get-AppxPackageAutoUpdateSettings -Scope Global -Force
    Set-Alias Remove-AppPackageAutoUpdateSettings Remove-AppxPackageAutoUpdateSettings -Scope Global -Force
    Set-Alias Set-AppPackageAutoUpdateSettings Set-AppxPackageAutoUpdateSettings -Scope Global -Force
    Set-Alias Reset-AppPackage Reset-AppxPackage -Scope Global -Force
    Set-Alias Add-MsixPackage Add-AppxPackage -Scope Global -Force
    Set-Alias Get-MsixPackage Get-AppxPackage -Scope Global -Force
    Set-Alias Remove-MsixPackage Remove-AppxPackage -Scope Global -Force
    Write-Log "AppX compatibility aliases created successfully"
} catch {
    Write-Log "Warning: Could not create some AppX aliases: $($_.Exception.Message)"
}

$packages = @(
    'Microsoft.Microsoft3DViewer'
    'Microsoft.MixedReality.Portal'
    'Microsoft.BingSearch'
    'Microsoft.BingNews'
    'Microsoft.BingWeather'
    'Microsoft.WindowsCamera'
    'Clipchamp.Clipchamp'
    'Microsoft.WindowsAlarms'
    'Microsoft.549981C3F5F10'
    'Microsoft.GetHelp'
    'Microsoft.Windows.DevHome'
    'MicrosoftCorporationII.MicrosoftFamily'
    'microsoft.windowscommunicationsapps'
    'Microsoft.SkypeApp'
    'MSTeams'
    'Microsoft.WindowsFeedbackHub'
    'Microsoft.WindowsMaps'
    'Microsoft.MicrosoftOfficeHub'
    'Microsoft.OutlookForWindows'
    'Microsoft.MSPaint'
    'Microsoft.Windows.Photos'
    'Microsoft.People'
    'Microsoft.PowerAutomateDesktop'
    'MicrosoftCorporationII.QuickAssist'
    'Microsoft.MicrosoftSolitaireCollection'
    'Microsoft.GamingApp'
    'Microsoft.XboxApp'
    'Microsoft.XboxIdentityProvider'
    'Microsoft.XboxGameOverlay'
    'Microsoft.Xbox.TCUI'
    'Microsoft.XboxGamingOverlay'
    'Microsoft.WindowsStore'
    'Microsoft.ZuneMusic'
    'Microsoft.ZuneVideo'
    'Microsoft.WindowsSoundRecorder'
    'Microsoft.MicrosoftStickyNotes'
    'Microsoft.Getstarted'
    'Microsoft.Todos'
    'Microsoft.YourPhone'
    'Microsoft.Copilot'
    'Microsoft.Windows.Ai.Copilot.Provider'
    'Microsoft.Copilot_8wekyb3d8bbwe'
    'Microsoft.Office.OneNote'
)

$capabilities = @(
    'Microsoft.Windows.PowerShell.ISE'
    'App.Support.QuickAssist'
    'App.StepsRecorder'
    'Microsoft.Windows.WordPad'
)

$optionalFeatures = @(
    'Recall'
)

$specialApps = @(
    'OneNote'
)

$maxRetries = 3
$retryCount = 0

do {
    $retryCount++
    Write-Log "Standard removal attempt $retryCount of $maxRetries"

    Write-Log "Discovering all packages..."
    $allInstalledPackages = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    $allProvisionedPackages = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue

    Write-Log "Processing packages..."
    $packagesToRemove = @()
    $provisionedPackagesToRemove = @()
    $notFoundPackages = @()

    foreach ($package in $packages) {
        $foundAny = $false

        $installedPackages = $allInstalledPackages | Where-Object { $_.Name -eq $package }
        if ($installedPackages) {
            Write-Log "Found installed package: $package"
            foreach ($pkg in $installedPackages) {
                Write-Log "Queuing installed package for removal: $($pkg.PackageFullName)"
                $packagesToRemove += $pkg.PackageFullName
            }
            $foundAny = $true
        }

        $provisionedPackages = $allProvisionedPackages | Where-Object { $_.DisplayName -eq $package }
        if ($provisionedPackages) {
            Write-Log "Found provisioned package: $package"
            foreach ($pkg in $provisionedPackages) {
                Write-Log "Queuing provisioned package for removal: $($pkg.PackageName)"
                $provisionedPackagesToRemove += $pkg.PackageName
            }
            $foundAny = $true
        }

        if (-not $foundAny) {
            $notFoundPackages += $package
        }
    }

    if ($notFoundPackages.Count -gt 0) {
        Write-Log "Packages not found: $($notFoundPackages -join ', ')"
    }

    if ($packagesToRemove.Count -gt 0) {
        Write-Log "Removing $($packagesToRemove.Count) installed packages in batch..."
        try {
            $packagesToRemove | ForEach-Object {
                Write-Log "Removing installed package: $_"
                Remove-AppxPackage -Package $_ -AllUsers -ErrorAction SilentlyContinue
            }
            Write-Log "Batch removal of installed packages completed"
        } catch {
            Write-Log "Error in batch removal of installed packages: $($_.Exception.Message)"
        }
    }

    if ($provisionedPackagesToRemove.Count -gt 0) {
        Write-Log "Removing $($provisionedPackagesToRemove.Count) provisioned packages..."
        foreach ($pkgName in $provisionedPackagesToRemove) {
            try {
                Write-Log "Removing provisioned package: $pkgName"
                Remove-AppxProvisionedPackage -Online -PackageName $pkgName -ErrorAction SilentlyContinue
            } catch {
                Write-Log "Error removing provisioned package $pkgName : $($_.Exception.Message)"
            }
        }
        Write-Log "Provisioned packages removal completed"
    }

    Write-Log "Processing capabilities..."
    foreach ($capability in $capabilities) {
        Write-Log "Checking capability: $capability"
        try {
            $matchingCapabilities = Get-WindowsCapability -Online | Where-Object { $_.Name -like "$capability*" -or $_.Name -like "$capability~~~~*" }

            if ($matchingCapabilities) {
                $foundInstalled = $false
                foreach ($existingCapability in $matchingCapabilities) {
                    if ($existingCapability.State -eq "Installed") {
                        $foundInstalled = $true
                        Write-Log "Removing capability: $($existingCapability.Name)"
                        Remove-WindowsCapability -Online -Name $existingCapability.Name -ErrorAction SilentlyContinue | Out-Null
                    }
                }

                if (-not $foundInstalled) {
                    Write-Log "Found capability $capability but it is not installed"
                }
            }
            else {
                Write-Log "No matching capabilities found for: $capability"
            }
        }
        catch {
            Write-Log "Error checking capability: $capability - $($_.Exception.Message)"
        }
    }

    Write-Log "Processing optional features..."
    if ($optionalFeatures.Count -gt 0) {
        $enabledFeatures = @()
        foreach ($feature in $optionalFeatures) {
            Write-Log "Checking feature: $feature"
            $existingFeature = Get-WindowsOptionalFeature -Online -FeatureName $feature -ErrorAction SilentlyContinue
            if ($existingFeature -and $existingFeature.State -eq "Enabled") {
                $enabledFeatures += $feature
            } else {
                Write-Log "Feature not found or not enabled: $feature"
            }
        }

        if ($enabledFeatures.Count -gt 0) {
            Write-Log "Disabling features: $($enabledFeatures -join ', ')"
            Disable-WindowsOptionalFeature -Online -FeatureName $enabledFeatures -NoRestart -ErrorAction SilentlyContinue | Out-Null
        }
    }

    Write-Log "Verifying removal results..."
    $remainingItems = @()

    $currentPackages = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    foreach ($package in $packages) {
        if ($currentPackages | Where-Object { $_.Name -eq $package }) {
            $remainingItems += $package
            Write-Log "Package still installed: $package"
        }
    }

    $currentCapabilities = Get-WindowsCapability -Online -ErrorAction SilentlyContinue | Where-Object State -eq 'Installed'
    foreach ($capability in $capabilities) {
        if ($currentCapabilities | Where-Object { $_.Name -like "$capability*" }) {
            $remainingItems += $capability
            Write-Log "Capability still installed: $capability"
        }
    }

    $currentFeatures = Get-WindowsOptionalFeature -Online -ErrorAction SilentlyContinue | Where-Object State -eq 'Enabled'
    foreach ($feature in $optionalFeatures) {
        if ($currentFeatures | Where-Object { $_.FeatureName -eq $feature }) {
            $remainingItems += $feature
            Write-Log "Feature still enabled: $feature"
        }
    }

    if ($remainingItems.Count -eq 0) {
        Write-Log "All standard items successfully removed!"
        break
    } else {
        Write-Log "Retry needed. $($remainingItems.Count) items remain: $($remainingItems -join ', ')"
        if ($retryCount -lt $maxRetries) {
            Write-Log "Waiting 2 seconds before retry..."
            Start-Sleep -Seconds 2
        }
    }

} while ($retryCount -lt $maxRetries -and $remainingItems.Count -gt 0)

if ($remainingItems.Count -gt 0) {
    Write-Log "Warning: $($remainingItems.Count) standard items could not be removed after $maxRetries attempts: $($remainingItems -join ', ')"
}

## One drive and teams taken from https://github.com/chef/bento/blob/main/packer_templates/scripts/windows/remove-one-drive-and-teams.ps1
Write-Log 'Removing OneDrive'
function force-mkdir($path) {
    if (!(Test-Path $path)) {
        #Write-Host "-- Creating full path to: " $path -ForegroundColor White -BackgroundColor DarkGreen
        New-Item -ItemType Directory -Force -Path $path
    }}

function Takeown-Registry($key) {
    # TODO does not work for all root keys yet
    switch ($key.split('\')[0]) {
        "HKEY_CLASSES_ROOT" {
            $reg = [Microsoft.Win32.Registry]::ClassesRoot
            $key = $key.substring(18)
        }
        "HKEY_CURRENT_USER" {
            $reg = [Microsoft.Win32.Registry]::CurrentUser
            $key = $key.substring(18)
        }
        "HKEY_LOCAL_MACHINE" {
            $reg = [Microsoft.Win32.Registry]::LocalMachine
            $key = $key.substring(19)
        }
    }

    # get administrator group
    $admins = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-544")
    $admins = $admins.Translate([System.Security.Principal.NTAccount])

    # set owner
    $key = $reg.OpenSubKey($key, "ReadWriteSubTree", "TakeOwnership")
    $acl = $key.GetAccessControl()
    $acl.SetOwner($admins)
    $key.SetAccessControl($acl)

    # set FullControl
    $acl = $key.GetAccessControl()
    $rule = New-Object System.Security.AccessControl.RegistryAccessRule($admins, "FullControl", "Allow")
    $acl.SetAccessRule($rule)
    $key.SetAccessControl($acl)
}

function Takeown-File($path) {
    takeown.exe /A /F $path
    $acl = Get-Acl $path

    # get administraor group
    $admins = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-544")
    $admins = $admins.Translate([System.Security.Principal.NTAccount])

    # add NT Authority\SYSTEM
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($admins, "FullControl", "None", "None", "Allow")
    $acl.AddAccessRule($rule)

    Set-Acl -Path $path -AclObject $acl
}

function Takeown-Folder($path) {
    Takeown-File $path
    foreach ($item in Get-ChildItem $path) {
        if (Test-Path $item -PathType Container) {
            Takeown-Folder $item.FullName
        } else {
            Takeown-File $item.FullName
        }
    }
}

function Elevate-Privileges {
    param($Privilege)
    $Definition = @"
    using System;
    using System.Runtime.InteropServices;
    public class AdjPriv {
        [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
            internal static extern bool AdjustTokenPrivileges(IntPtr htok, bool disall, ref TokPriv1Luid newst, int len, IntPtr prev, IntPtr rele);
        [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
            internal static extern bool OpenProcessToken(IntPtr h, int acc, ref IntPtr phtok);
        [DllImport("advapi32.dll", SetLastError = true)]
            internal static extern bool LookupPrivilegeValue(string host, string name, ref long pluid);
        [StructLayout(LayoutKind.Sequential, Pack = 1)]
            internal struct TokPriv1Luid {
                public int Count;
                public long Luid;
                public int Attr;
            }
        internal const int SE_PRIVILEGE_ENABLED = 0x00000002;
        internal const int TOKEN_QUERY = 0x00000008;
        internal const int TOKEN_ADJUST_PRIVILEGES = 0x00000020;
        public static bool EnablePrivilege(long processHandle, string privilege) {
            bool retVal;
            TokPriv1Luid tp;
            IntPtr hproc = new IntPtr(processHandle);
            IntPtr htok = IntPtr.Zero;
            retVal = OpenProcessToken(hproc, TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, ref htok);
            tp.Count = 1;
            tp.Luid = 0;
            tp.Attr = SE_PRIVILEGE_ENABLED;
            retVal = LookupPrivilegeValue(null, privilege, ref tp.Luid);
            retVal = AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
            return retVal;
        }
    }
"@
    $ProcessHandle = (Get-Process -id $pid).Handle
    $type = Add-Type $definition -PassThru
    $type[0]::EnablePrivilege($processHandle, $Privilege)
}

Write-Log "Kill OneDrive process and explorer"
taskkill.exe /F /IM "OneDrive.exe"
taskkill.exe /F /IM "explorer.exe"

Write-Log "Remove OneDrive"
if (Test-Path "$env:systemroot\System32\OneDriveSetup.exe") {
    & "$env:systemroot\System32\OneDriveSetup.exe" /uninstall
}
if (Test-Path "$env:systemroot\SysWOW64\OneDriveSetup.exe") {
    & "$env:systemroot\SysWOW64\OneDriveSetup.exe" /uninstall
}

Write-Log "Disable OneDrive via Group Policies"
force-mkdir "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\OneDrive"
Set-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\OneDrive" -Name DisableFileSyncNGSC -Value 1

Write-Log "Removing OneDrive leftovers trash"
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "$env:localappdata\Microsoft\OneDrive"
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "$env:programdata\Microsoft OneDrive"
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "C:\OneDriveTemp"

Write-Log "Remove Onedrive from explorer sidebar"
New-PSDrive -PSProvider "Registry" -Root "HKEY_CLASSES_ROOT" -Name "HKCR"
mkdir -Force "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
Set-ItemProperty "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" -Name System.IsPinnedToNameSpaceTree -Value 0
mkdir -Force "HKCR:\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
Set-ItemProperty "HKCR:\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" -Name System.IsPinnedToNameSpaceTree -Value 0
Remove-PSDrive "HKCR"

Write-Log "Removing run option for new users"
reg load "hku\Default" "C:\Users\Default\NTUSER.DAT"
reg delete "HKEY_USERS\Default\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "OneDriveSetup" /f
reg unload "hku\Default"

Write-Log "Removing startmenu junk entry"
rm -Force -ErrorAction SilentlyContinue "$env:userprofile\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\OneDrive.lnk"

Write-Log "Restarting explorer..."
start "explorer.exe"

Write-Log "Wait for EX reload.."
sleep 15

Write-Log "Removing additional OneDrive leftovers"
foreach ($item in (ls "$env:WinDir\WinSxS\*onedrive*")) {
    Takeown-Folder $item.FullName
    rm -Recurse -Force $item.FullName -ErrorAction SilentlyContinue
}

###########################################################################################
Write-Log "Removing Teams"
# Clearing Teams Cache by Mark Vale
# Uninstall Teams by Rudy Mens

Write-Log "Stopping Teams Process" -ForegroundColor Yellow
try{
    Get-Process -ProcessName Teams | Stop-Process -Force
    Start-Sleep -Seconds 3
    Write-Log "Teams Process Sucessfully Stopped" -ForegroundColor Green
}catch{
    Write-Log $_ "ERROR"
}

Write-Log "Clearing Teams Disk Cache" -ForegroundColor Yellow
try{
    Get-ChildItem -Path $env:APPDATA\"Microsoft\teams\application cache\cache" | Remove-Item -Confirm:$false
    Get-ChildItem -Path $env:APPDATA\"Microsoft\teams\blob_storage" | Remove-Item -Confirm:$false
    Get-ChildItem -Path $env:APPDATA\"Microsoft\teams\databases" | Remove-Item -Confirm:$false
    Get-ChildItem -Path $env:APPDATA\"Microsoft\teams\cache" | Remove-Item -Confirm:$false
    Get-ChildItem -Path $env:APPDATA\"Microsoft\teams\gpucache" | Remove-Item -Confirm:$false
    Get-ChildItem -Path $env:APPDATA\"Microsoft\teams\Indexeddb" | Remove-Item -Confirm:$false
    Get-ChildItem -Path $env:APPDATA\"Microsoft\teams\Local Storage" | Remove-Item -Confirm:$false
    Get-ChildItem -Path $env:APPDATA\"Microsoft\teams\tmp" | Remove-Item -Confirm:$false
    Write-Host "Teams Disk Cache Cleaned" -ForegroundColor Green
}catch{
    Write-Host $_ "ERROR"
}

Write-Log "Stopping IE Process" -ForegroundColor Yellow
try{
    Get-Process -ProcessName MicrosoftEdge | Stop-Process -Force
    Get-Process -ProcessName IExplore | Stop-Process -Force
    Write-Host "Internet Explorer and Edge Processes Sucessfully Stopped" -ForegroundColor Green
}catch{
    Write-Log $_ "ERROR"
}

Write-Log "Clearing IE Cache" -ForegroundColor Yellow
try{
    RunDll32.exe InetCpl.cpl, ClearMyTracksByProcess 8
    RunDll32.exe InetCpl.cpl, ClearMyTracksByProcess 2
    Write-Log "IE and Edge Cleaned" -ForegroundColor Green
}catch{
    Write-Log $_ "ERROR"
}
Write-Log "Cleanup Complete..."


Write-Log "Removing Teams Machine-wide Installer"
try
{
    $MachineWide = Get-WmiObject -Class Win32_Product | Where-Object{$_.Name -eq "Teams Machine-Wide Installer"}
    $MachineWide.Uninstall()
}
catch
{
    Write-Log $_ "WARNING"
}

function unInstallTeams($path) {
    $clientInstaller = "$($path)\Update.exe"
    try {
        $process = Start-Process -FilePath "$clientInstaller" -ArgumentList "--uninstall /s" -PassThru -Wait -ErrorAction STOP
        if ($process.ExitCode -ne 0)
        {
            Write-Warning "UnInstallation failed with exit code  $($process.ExitCode)."
        }
    }
    catch {
        Write-Log $_.Exception.Message "WARNING"
    }
}

#Locate installation folder
$localAppData = "$($env:LOCALAPPDATA)\Microsoft\Teams"
$programData = "$($env:ProgramData)\$($env:USERNAME)\Microsoft\Teams"

If (Test-Path "$($localAppData)\Current\Teams.exe")
{
    unInstallTeams($localAppData)
}
elseif (Test-Path "$($programData)\Current\Teams.exe") {
    unInstallTeams($programData)
}
else {
    Write-Warning  "Teams installation not found"
}