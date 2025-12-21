// Common locals shared by VirtualBox and VMware sources

locals {
  image_name       = var.image_name
  shutdown_command = "shutdown /s /t 10 /f /d p:4:1 /c \"Packer Shutdown\""
  boot_command     = ["<enter><wait><enter><wait><enter>"]
  boot_wait        = "1s"
  cd_files         = ["../scripts/first-logon.ps1", "../scripts/setup.cmd"]
  cd_content = {
    "autounattend.xml" = templatefile("${path.root}/autounattend.xml", { local = { image_name = var.image_name } })
  }
}


