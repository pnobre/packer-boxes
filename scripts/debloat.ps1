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