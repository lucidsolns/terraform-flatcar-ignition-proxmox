**Deprecated**: I've moved to using the bpg/proxmox provider as in this [example](https://github.com/lucidsolns/tf-proxmox-cacti-cyan).

# A sample Proxmox Terraform Flatcar provisioning script

This repository has a script to provision Flatcar VM images using
Butane and Ignition from a preconfigured template VM. This is a second
attempt to get this working. The [first](git@github.com:lucidsolns/terraform-flatcar-ignition-proxmox.git)
attempt worked but was limited to an 8kbyte ignition file due to length
restrictions in the 'description' (notes) field of the VM configuration.

This script uses a strategy of hijacking the cloud-init ISO to transfer the
ignition JSON configuration into Proxmox. Once the configuration is on the proxmox
server the ignition configuration is extracted from the cloud-init ISO using
a hook script into the `/etc/pve/local/ignition/` directory, where it is picked
up directly by QEMU via the `-fw_cfg` `file=` directive. 

A helper script is provided to manually provision a Proxmox VM template for
Flatcar. This is a versioned resource so that new versions of Flatcar can be
used for new VM's.

**IMPORTANT:** This is all just a massive big ~~hack~~ workaround, until Proxmox has first class support
for provisioning ignition and/or butane configurations.

**Note:** A snippet has not been used as there is no API support for creating snippets and
based on feedback in the bug tracker there is little support for adding snippet support
to the API. 

## Usage

To use the sample, set a `credentials.auto.tfvars` with the root username/password:

```terraform
pm_user         = "root@pam"
pm_password     = "password"
```

## Template creation

The `make_template.sh` script is provided to create a Proxmox template VM using the
Flatcar linux production qemu image.

Download the images (assuming a stable release is used):

```shell
wget https://stable.release.flatcar-linux.net/amd64-usr/current/flatcar_production_qemu_uefi_efi_code.fd 
wget https://stable.release.flatcar-linux.net/amd64-usr/current/flatcar_production_qemu_uefi_efi_vars.fd 
wget https://stable.release.flatcar-linux.net/amd64-usr/current/flatcar_production_qemu_uefi_image.img.bz2 
bunzip2 flatcar_production_qemu_uefi_image.img.bz2
```
Create the template VM using the images.
```shell
./make_template.sh -n flatcar-production-qemu-3510.2.6 900
```
The *vars* image is used as the UEFI read-write variables device and the *code* image is a
read-only UEFI code device. 

## Known Limitations

As of September 2023, the following limitation and residuals have been observed:

1. The Proxmox API requires the 'root@pam' user to provision 'args'. Using
   an API key doesn't work, and using an API key for root also doesn't work,
   as the username 'root@pam!terraform' doesn't match the required identity of 'root@pam'.

2. The Qemu command line parsing requires the Ignition configuration to have all
   comma's escaped with another comma (i.e. a double comma). This means it is far
   easier and more successful to use the 'file=' option (rather than 'string=') 
   fw_cfg option.

3. Ignition support in Flatcar Linux **Stable** is limited to Butane version 1.0.0 with the generated
   ignition files being v3.3.0 using ct provider v0.12 (**important**: do not use latest ct provider).

4. When creating a Proxmox UEFI VM with a pre-made image, the special `file=<storage>:0`
   syntax must be used. e.g. if the node local disk is called 'local' then the syntax would be:
```
   --efidisk0 "file=local:0,import-from=flatcar_production_qemu_image.img,efitype=4m,format=raw,pre-enrolled-keys=1"
```

5. Although the flatcar linux qemu image has a `.img` extension, it is
   a [qcow2](https://en.wikipedia.org/wiki/Qcow) formatted file. The image has multiple partitions.

6. The documentation isn't clear as to the correct way to mount UEFI code partitions as
   a read-only volume. It is unclear how to specify a pflash drive for the UEFI code. To see
   the Qemu configuration run `qm showcmd <vm id> --pretty`, which shows the two EFI
   pflash drives.

7. Terraform Telmate/Proxmox provider doesn't support setting the hookscript upon create, thus
   the hookscript must be set in the template and inherited to child VM's.

8. The proxmox hook script locks the vm configuration - thus stopping the hook script
   from modifying/mutating the configuration. Even if the configuration is changed the
   Proxmox *start* code will not reload the changes after the hookscript runs.

9. There appears to be limitation on the length of the ignition file to about 8k when 
   it is put into the description field.
   It is unclear where this limitation is imposed, as the internal code seems to limit
   the description field to 64kbytes. This renders the strategy of hijacking the description
   field as ineffective for all but trivial VM's.

# Links

- https://austinsnerdythings.com/2021/09/01/how-to-deploy-vms-in-proxmox-with-terraform/

### Flatcar

- https://www.flatcar.org/
- Flatcar releases (https://www.flatcar.org/releases)
- https://www.flatcar.org/docs/latest/installing/vms/libvirt/
- https://github.com/flatcar/Flatcar/issues/430
- https://github.com/flatcar/ignition

### Ignition
- https://coreos.github.io/ignition
- https://github.com/flatcar/ignition
- https://www.iana.org/assignments/media-types/application/vnd.coreos.ignition+json

### Terraform

- https://registry.terraform.io/providers/Telmate/proxmox/latest
- https://registry.terraform.io/providers/Telmate/proxmox/latest/docs/resources/vm_qemu
- https://github.com/poseidon/terraform-provider-ct
- https://registry.terraform.io/providers/poseidon/ct/latest/docs
- https://www.flatcar.org/docs/latest/provisioning/config-transpiler/


### Proxmox
- https://pve.proxmox.com/wiki/Manual:_qm.conf

### Qemu
- https://github.com/qemu/qemu/blob/master/docs/specs/fw_cfg.rst
- https://www.qemu.org/docs/master/specs/fw_cfg.html

### UEFI
- https://joonas.fi/2021/02/uefi-pc-boot-process-and-uefi-with-qemu/#uefi-is-not-bios

