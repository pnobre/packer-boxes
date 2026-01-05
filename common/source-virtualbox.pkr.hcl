// VirtualBox source definition

source "virtualbox-iso" "windows" {
  vm_name              = "${var.vm_name}-virtualbox"
  guest_os_type        = var.guest_os_type_virtualbox
  iso_url              = var.iso_url
  iso_checksum         = var.iso_checksum
  communicator         = "ssh"
  ssh_username         = var.ssh_username
  ssh_password         = var.ssh_password
  ssh_timeout          = var.ssh_timeout
  shutdown_command     = local.shutdown_command
  shutdown_timeout     = var.shutdown_timeout
  cd_content           = local.cd_content
  cd_files             = local.cd_files
  boot_command         = local.boot_command
  boot_wait            = local.boot_wait
  cpus                 = var.cpus
  nested_virt          = "true"
  memory               = var.memory
  disk_size            = var.disk_size
  firmware             = "efi"
  gfx_controller       = "vboxsvga"
  gfx_vram_size        = 128
  gfx_accelerate_3d    = true
  hard_drive_interface = "sata"
  iso_interface        = "sata"
  guest_additions_mode = "upload"
  guest_additions_path = "VBoxGuestAdditions.iso"
  output_directory     = "../build/${var.vm_name}/virtualbox"
}
