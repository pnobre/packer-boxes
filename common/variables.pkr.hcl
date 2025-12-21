// Common variables for all Windows box builds

variable "iso_url" {
  type        = string
  description = "Path or URL to the Windows ISO file"
}

variable "iso_checksum" {
  type        = string
  description = "SHA256 checksum of the ISO file"
}

variable "vm_name" {
  type        = string
  description = "Name of the virtual machine"
}

variable "image_name" {
  type        = string
  description = "Image name used for autounattend.xml templating (windows-10, windows-11, windows-server-2025)"
}

variable "guest_os_type_virtualbox" {
  type        = string
  description = "VirtualBox guest OS type (e.g., Windows10_64, Windows11_64, Windows2022_64)"
}

variable "guest_os_type_vmware" {
  type        = string
  description = "VMware guest OS type (e.g., windows9-64, windows11-64, windows2022srvnext-64)"
}

variable "cpus" {
  type    = number
  default = 4
}

variable "memory" {
  type    = number
  default = 8192
}

variable "disk_size" {
  type    = number
  default = 61440  # 60 GB
}

variable "locale" {
  type    = string
  default = "en-IE"
}

variable "timezone" {
  type    = string
  default = "GMT Standard Time"
}

variable "theme" {
  type    = string
  default = "Light"
  validation {
    condition     = contains(["Light", "Dark"], var.theme)
    error_message = "Theme must be either 'Light' or 'Dark'."
  }
}

variable "ssh_username" {
  type    = string
  default = "Administrator"
}

variable "ssh_password" {
  type    = string
  default = "P@ssword1"
}

variable "ssh_timeout" {
  type    = string
  default = "30m"
}

variable "shutdown_timeout" {
  type    = string
  default = "5m"
}

packer {
  required_plugins {
    vmware = {
      version = "~> 1"
      source  = "github.com/hashicorp/vmware"
    }
    vagrant = {
      version = "~> 1"
      source  = "github.com/hashicorp/vagrant"
    }
    virtualbox = {
      version = "~> 1"
      source  = "github.com/hashicorp/virtualbox"
    }
  }
}
