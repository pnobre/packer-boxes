Write-Host "Installing Chocolatey"
If ((Get-Command "choco" -ErrorAction Ignore).Count -eq 0)
{ 
  Set-ExecutionPolicy Bypass -Scope Process -Force
  [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
  Invoke-WebRequest "https://community.chocolatey.org/install.ps1" -UseBasicParsing | Invoke-Expression
}

Write-Host "Installing OpenSSH"
choco install openssh -y -params '"/SSHServerFeature"'
New-NetFirewallRule -DisplayName "Packer - Allow OpenSSH" -Direction Inbound -LocalPort 22 -Protocol TCP -Action Allow
$SSHDService = Get-Service sshd 
if ($SSHDService.Status -ne "Running")
{ 
  Get-Service sshd | Start-Service 
}

if ($SSHDService.StartType -ne "Automatic")
{ 
  Get-Service sshd | Set-Service -StartupType Automatic 
}
$sshd_config = "$(env:ProgramData)\ssh\sshd_config"
(Get-Content $sshd_config).Replace("Match Group administrators", "# Match Group administrators") | Set-Content $sshd_config
(Get-Content $sshd_config).Replace("AuthorizedKeysFile", "# AuthorizedKeysFile") | Set-Content $sshd_config 

# Enable WinRM 
Write-Host "Installing WinRM.1"
netsh advfirewall firewall add rule name="WinRM-Install" dir=in localport=5985 protocol=TCP action=block
Write-Host "Installing WinRM.2"
Get-NetConnectionProfile | ForEach-Object { Set-NetConnectionProfile -InterfaceIndex $_.InterfaceIndex -NetworkCategory Private }
Write-Host "Installing WinRM.3"
winrm quickconfig -q
Write-Host "Installing WinRM.4"
winrm quickconfig -transport:http
Write-Host "Installing WinRM.5"
winrm set winrm/config '@{MaxTimeoutms="1800000"}'
Write-Host "Installing WinRM.6"
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="800"}'
Write-Host "Installing WinRM.7"
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
Write-Host "Installing WinRM.8"
winrm set winrm/config/service/auth '@{Basic="true"}'
Write-Host "Installing WinRM.9"
winrm set winrm/config/client/auth '@{Basic="true"}'
Write-Host "Installing WinRM.10"
net stop winrm
Write-Host "Installing WinRM.11"
netsh advfirewall firewall delete rule name="WinRM-Install"

Write-Host "Configuring WinRM"
net start winrm
sc.exe config winrm start=auto
netsh advfirewall firewall add rule name="Packer - Allow WinRM" dir=in localport=5985 protocol=TCP action=allow


