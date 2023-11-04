/**
  Provision a VM with an ignition configuration file.

  see
    - https://registry.terraform.io/providers/Telmate/proxmox/latest/docs/resources/vm_qemu
    - https://pve.proxmox.com/wiki/Manual:_qm.conf
    - https://github.com/qemu/qemu/blob/master/docs/specs/fw_cfg.rst
    - https://www.flatcar.org/docs/latest/installing/vms/libvirt/
    - https://austinsnerdythings.com/2021/09/01/how-to-deploy-vms-in-proxmox-with-terraform/
    - https://www.flatcar.org/
    - https://github.com/flatcar/ignition
    - https://www.qemu.org/docs/master/specs/fw_cfg.html
*/
resource "proxmox_vm_qemu" "example_flatcar_ignition_vm" {
  count       = var.vm_count # just want 1 for now, set to 0 and apply to destroy VM
  vmid        = var.vm_count > 1 ? var.vm_id + count.index : var.vm_id
  name        = var.vm_count > 1 ? "${var.name}-${count.index + 1}" : var.name
  target_node = var.target_node

  # Create a VM using the flatcar qemu image, and give it a version. This will mean
  # a linked clone can be used to reduce the storage requirements when a large number
  # of clones are created.
  #
  # Download the flatcar_qemu image from https://www.flatcar.org/releases and
  clone      = var.template_name
  full_clone = false
  clone_wait = 0

  /*
   The 'arguments' parameter for QEMU is parsed in such a way that the string is not
   treated opaquely. The options are split at comma's (',') causing ambiguity with
   options without a value.

   The doubling up of comma's in the fw_cfg configuration overcomes this limitation.
   This is documented in the Qemu documentation in the 'blockdev drive -file' section.

   Setting this args parameter when creating a VM requires local root access
   with password authentication. The ignition file is created in the `/etc/pve/...`
   directory by the helper hook script.
 */
  args = "-fw_cfg name=opt/org.flatcar-linux/config,file=/etc/pve/local/ignition/${var.vm_count > 1 ? var.vm_id + count.index : var.vm_id}.ign"
  desc = <<-EOT
      A flatcar VM provisioned with Terraform from template ${var.template_name} on ${timestamp()}

      hook-script: local:snippets/cloudinit-to-ignition
      cloud-init: ${proxmox_cloud_init_disk.ignition_cloud_init[count.index].id}
  EOT

  /*
    Enable serial port support. Where the guest provides serial console
    support (which flatcar does out of the box), diagnostics around booting
    and crashing is vastly simplified.

   Use the following command to access the serial port/terminal:
       qm terminal <vm_id>

    This should create QEMU equivalent option:
        -serial unix:/var/run/qemu-server/101.serial,server,nowait

   see:
      - https://pve.proxmox.com/wiki/Serial_Terminal
  */
  serial {
    id   = 0
    type = "socket"
  }

  # The qemu agent must be running in the flatcar instance so that Proxmox can
  # identify when the VM is up (see https://github.com/flatcar/Flatcar/issues/737)
  agent = 1
  timeouts {
    # use terraform timeouts instead of 'guest_agent_ready_timeout'
    create  = "60s"
    update  = "60s"
    default = "120s"
  }

  # The connection info is obtained via the guest agent once the VM is
  # up and running. This requires the ignition configuration to 'work' and the
  # agent to be running. This will provide feedback that the VM is operational.
  #
  # If this fails, the following error is produced:
  #      Warning: define_connection_info is %t, no further action.
  define_connection_info = true

  #
  bios = "ovmf" # UEFI boot

  # There seems to be an issue here with duplication
  os_type = var.os_type  # qemu identifier
  qemu_os = var.os_type  # qemu identifier

  cores   = var.cores
  sockets = 1
  cpu     = var.cpu
  memory  = var.memory
  tags    = join(";", sort(var.tags)) # Proxmox sorts the tags, so sort them here to stop change thrash
  onboot  = true
  scsihw  = "virtio-scsi-single"

  // Support an array of virtio network adapters.
  dynamic "network" {
    for_each = var.networks
    content {
      model  = "virtio"
      bridge = lookup(network.value, "bridge", "vmbr0")
      tag    = lookup(network.value, "tag", null)
      mtu    = lookup(network.value, "mtu", null)
    }
  }

  // Support a list of optional disks (in addition to those inherited from the cloned
  // template). Getting these expressed so they don't conflict with disks inherited
  // from the template can be problematic (use slots).
  dynamic "disk" {
    for_each = var.disks
    content {
      type    = lookup(disk.value, "type", "virtio")
      storage = lookup(disk.value, "storage", null)
      size    = lookup(disk.value, "size", null)
      slot    = lookup(disk.value, "slot", null)
      volume  = lookup(disk.value, "volume", null)
      file    = lookup(disk.value, "file", null)
      format  = lookup(disk.value, "format", null)
    }
  }

  lifecycle {
    prevent_destroy       = false # this resource should be immutable **and** disposable
    create_before_destroy = false
    ignore_changes        = [
      disk, # the disk is provisioned in the template and inherited (but not defined here]
      desc # the description on the first start, then the user can change it in the UI
    ]
    replace_triggered_by = [
      null_resource.node_replace_trigger[count.index].id
    ]
  }
}

/**
    Convert a butane configuration to an ignition JSON configuration. The template supports
    multiple instances (a count) so that each configuration can be slightly changed.

    see
      - https://github.com/poseidon/terraform-provider-ct
      - https://registry.terraform.io/providers/poseidon/ct/latest
      - https://registry.terraform.io/providers/poseidon/ct/latest/docs
      - https://www.flatcar.org/docs/latest/provisioning/config-transpiler/
      - https://developer.hashicorp.com/terraform/language/functions/templatefile
*/
data "ct_config" "ignition_json" {
  count   = var.vm_count
  content = templatefile(var.butane_conf, {
    "vm_id"          = var.vm_count > 1 ? var.vm_id + count.index : var.vm_id
    "vm_name"        = var.vm_count > 1 ? "${var.name}-${count.index + 1}" : var.name
    "vm_count"       = var.vm_count,
    "vm_count_index" = count.index,
  })
  strict       = true
  pretty_print = true

  snippets = [
    for snippet in var.butane_conf_snippets : templatefile(var.butane_conf, {
      "vm_id"          = var.vm_count > 1 ? var.vm_id + count.index : var.vm_id
      "vm_name"        = var.vm_count > 1 ? "${var.name}-${count.index + 1}" : var.name
      "vm_count"       = var.vm_count,
      "vm_count_index" = count.index,
    })
  ]
}

/*
  Create a cloudinit ISO with the ignition configuration as the `meta data` file.

  This is a blatant hack/hijack of the meta-data as the ignition file is not
  a cloud-init configuration. The ISO will not be attached to the VM and will have
  a lifeycle that is independent of the VM (i.e. if the VM is deleted, then a manual
  deletion of the cloud-init ISO will be required).

  The ignition configuration is put into the ISO as plain text (it can be formatted/pretty
  or in a canonical form). No escaping, or base64 encoding is performed.

  see:
    - https://registry.terraform.io/providers/Telmate/proxmox/latest/docs/guides/cloud_init
*/
resource "proxmox_cloud_init_disk" "ignition_cloud_init" {
  count    = var.vm_count # just want 1 for now, set to 0 and apply to destroy VM
  name     = var.vm_count > 1 ? "${var.name}-${count.index + 1}" : var.name
  pve_node = var.target_node
  storage  = "local"

  meta_data = data.ct_config.ignition_json[count.index].rendered
}

/**
    A null resource to track changes, so that the immutable VM is recreated
 */
resource "null_resource" "node_replace_trigger" {
  count    = var.vm_count
  # Changes to any instance of the cluster requires re-provisioning
  triggers = {
    "ignition" = "${data.ct_config.ignition_json[count.index].rendered}"
  }
}