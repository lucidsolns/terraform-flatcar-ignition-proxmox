variable "name" {
  type        = string
  default     = "Flatcar-Linux"
  description = "The base name of the VM"
}

variable "butane_conf" {
  type        = string
  description = "YAML Butane configuration for the VM"
}
variable "butane_conf_snippets" {
  type        = list(string)
  default     = []
  description = "Additional YAML Butane configuration(s) for the VM"
}
variable "target_node" {
  description = "The name of the target proxmox node"
  type        = string
}
variable "storage" {
  description = "The name of the storage used for storing VM images"
  type        = string
  default     = "local"
}
/*
  The name of a VM that has been converted to a template. The creation of this
  process is manual, and has not been automated. The flatcar qemu image is a qcow2
  image, and not a raw disk image as the name implies.

  Steps:
    1. Download the latest flatcar qemu image (noting the version number)
           > wget https://stable.release.flatcar-linux.net/amd64-usr/3510.2.6/flatcar_production_qemu_image.img.bz2
    2. Create a new VM with the name 'flatcar-production-qemu-<version>' (e.g. flatcar-production-qemu-3510.2.6)
           - UEFI boot
           - with no network
           - with no disks
           - delete the CDROM
    3. Decompress the flatcar qcow2 image
           > bunzip2 flatcar_production_qemu_image.img.bz2
    4. Add the qcow2 image to the VM
           > qm importdisk 900 flatcar_production_qemu_image.img vmroot --format qcow2
    5. Adopt the new disk into the VM
           > qm set 900 -efidisk0 vm-900-disk-0.qcow2:0,format=qcow2,efitype=4m,pre-enrolled-keys=1
    6. Convert the VM to a Template

  see
    - https://www.flatcar.org/releases
*/
variable "vm_count" {
  description = "The number of VMs to provision"
  type        = number
  default     = 1
}
variable "template_name" {
  description = "The name of the Proxmox Flatcar template VM"
  type    = string
  default = "flatcar_qemu"
}
variable "vm_id" {
  type    = number
  default = 0
}
variable "cores" {
  type    = number
  default = 2
}
variable "cpu" {
  type        = string
  default     = "host"
  description = "e.g. x86-64-v2-AES"
}
variable "memory" {
  type    = number
  default = 2048
}

variable "os_type" {
  type        = string
  default     = "l26"
  description = "The short OS name identifier"
}

variable "os_type_name" {
  type        = string
  default     = "Linux 2.6 - 6.X Kernel"
  description = "os_type_name='Linux 2.6 - 6.X Kernel'"
}


variable "pm_api_url" {
  description = "The FQDN and path to the API of the proxmox server e.g. https://example.com:8006/api2/json"
  type        = string
}




variable "pm_user" {
  description = "A username for password based authentication of the Proxmox API"
  type        = string
  default     = ""
}

variable "pm_password" {
  description = "A password for password based authentication of the Proxmox API"
  type        = string
  sensitive   = true
  default     = ""
}

variable "pm_tls_insecure" {
  description = "leave tls_insecure set to true unless you have a valid proxmox SSL certificate "
  default     = true
  type        = bool
}
variable "tags" {
  description = "Tags to apply to the VM"
  type        = list(string)
  default     = ["flatcar"]
}


variable "networks" {
  description = "An ordered list of network interfaces"
  type        = list(object({
    bridge = optional(string, "vmbr0")
    tag    = optional(number)
    mtu    = optional(number)
  }))
  default = [
    {
      bridge = "vmbr0",
    }
  ]
}

variable "disks" {
  description = "An ordered list of disks"
  // see https://registry.terraform.io/providers/Telmate/proxmox/latest/docs/resources/vm_qemu#argument-reference
  type        = list(object({
    type    = string
    storage = string
    size    = string
    file    = optional(string)
    format  = optional(string)
    volume  = optional(string)
    slot    = optional(number)
  }))
  default = []
}
