// Common build definition with provisioners

build {
  sources = ["source.virtualbox-iso.windows", "source.vmware-iso.windows"]

  provisioner "file" {
    source      = "../scripts/utilities.ps1"
    destination = "C:\\Windows\\Temp\\utilities.ps1"
  }

  provisioner "file" {
    source      = "../scripts/provision.ps1"
    destination = "C:\\Windows\\Temp\\provision.ps1"
  }

  provisioner "file" {
    source      = "../scripts/debloat.ps1"
    destination = "C:\\Windows\\Temp\\debloat.ps1"
  }

  provisioner "file" {
    source      = "../scripts/cleanup.ps1"
    destination = "C:\\Windows\\Temp\\cleanup.ps1"
  }

  provisioner "powershell" {
    elevated_user     = local.elevated_user
    elevated_password = local.elevated_pass
    inline = [
      "$ErrorActionPreference = 'Stop'",
      "Set-ExecutionPolicy Bypass -Scope Process -Force",
      "& C:\\Windows\\Temp\\provision.ps1 -Locale \"${var.locale}\" -TimeZone \"${var.timezone}\" ${source.type == "virtualbox-iso" ? "-Hypervisor virtualbox" : "-Hypervisor vmware"} ${var.theme == "dark" ? "-UseDarkTheme" : ""}",
      "if ($LASTEXITCODE -ne 0) { throw 'provision.ps1 failed with exit code ' + $LASTEXITCODE }",
      "& C:\\Windows\\Temp\\debloat.ps1",
      "if ($LASTEXITCODE -ne 0) { throw 'debloat.ps1 failed with exit code ' + $LASTEXITCODE }"
    ]
  }

  provisioner "windows-restart" {
    restart_timeout = "30m"
  }

  provisioner "windows-update" {
    search_criteria = "IsInstalled=0 and IsHidden = 0"
    filters = [
      "exclude:$_.Title -like '*Preview*'",
      "exclude:$_.Title -like '*Cumulative Update for Microsoft server*'",
      "exclude:$_.Title -like '*Cumulative Update for Windows *'",
      "exclude:$_.Title -like '*-* Security Update*'", # New naming scheme for cumulative updates
      "exclude:$_.InstallationBehavior.CanRequestUserInput",
      "include:$true",
    ]
  }

  provisioner "windows-restart" {
    restart_timeout = "30m"
  }

  provisioner "powershell" {
    elevated_user     = local.elevated_user
    elevated_password = local.elevated_pass
    inline = [
      "$ErrorActionPreference = 'Stop'",
      "& C:\\Windows\\Temp\\cleanup.ps1",
      "if ($LASTEXITCODE -ne 0) { throw 'cleanup.ps1 failed with exit code ' + $LASTEXITCODE }"
    ]
  }

  post-processor "vagrant" {
    keep_input_artifact  = false
    compression_level    = 9
    output               = "../boxes/${var.vm_name}/{{.Provider}}/${var.vm_name}-{{.Provider}}.box"
    vagrantfile_template = "../vagrant/Vagrantfile.windows-template"
  }
}
