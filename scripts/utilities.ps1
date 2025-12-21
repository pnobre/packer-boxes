$LogPath = "$env:Windir\Logs\"
$LogFile = "$LogPath\provisioning.log"
if (!(Test-Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}

function Write-Log {
  param (
    [string]$Message,

    [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
    [string]$Level = "INFO"
  )
  $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $LogEntry = "[$Timestamp] [$Level] $Message"
  
  Add-Content -Path $LogFile -Value $LogEntry -Encoding UTF8
  
  Write-Host $LogEntry
}

function Set-RegistryKey {
    param (
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [string]$Type
    )
    
    if (!(Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type
    Write-Log "Set registry key: $Path\$Name = $Value (Type: $Type)" -Level "INFO"
}