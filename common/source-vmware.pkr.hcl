// VMware source definition

source "vmware-iso" "windows" {
  vm_name            = "${var.vm_name}-vmware"
  version            = 20
  guest_os_type      = var.guest_os_type_vmware
  iso_url            = var.iso_url
  iso_checksum       = var.iso_checksum
  communicator       = "ssh"
  ssh_username       = var.ssh_username
  ssh_password       = var.ssh_password
  ssh_timeout        = var.ssh_timeout
  shutdown_command   = local.shutdown_command
  shutdown_timeout   = var.shutdown_timeout
  cd_content         = local.cd_content
  cd_files           = local.cd_files
  boot_command       = local.boot_command
  boot_wait          = local.boot_wait
  cpus               = var.cpus
  memory             = var.memory
  disk_size          = var.disk_size
  vmx_data = {
    firmware         = "efi"
    "vhv.enable"     = "FALSE"
    "sata1.present"  = "TRUE"
  }
  disk_type_id       = 0
  disk_adapter_type  = "nvme"
  cdrom_adapter_type = "sata"
  tools_upload_flavor = "windows"
  tools_upload_path   = "C:\\Windows\\Temp\\VMwareTools.iso"
  output_directory   = "../build/${var.vm_name}/vmware"
}
