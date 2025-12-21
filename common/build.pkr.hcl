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
    inline = [
      "C:\\Windows\\Temp\\provision.ps1 ${var.theme == "Dark" ? "-UseDarkTheme" : ""} -Locale \"${var.locale}\" -TimeZone \"${var.timezone}\"",
      "C:\\Windows\\Temp\\debloat.ps1",
      "C:\\Windows\\Temp\\cleanup.ps1"
    ]
  }

  post-processor "vagrant" {
    keep_input_artifact  = false
    output               = "../build/${var.vm_name}/{{.Provider}}/${var.vm_name}-{{.Provider}}.box"
    vagrantfile_template = "../vagrant/Vagrantfile.windows-template"
  }

  post-processor "compress" {}
}
