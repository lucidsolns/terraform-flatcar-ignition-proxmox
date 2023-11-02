module "ignition-vm" {
  source        = "../../module/ignition-vm"
  pm_api_url    = var.pm_api_url
  pm_user       = var.pm_user
  pm_password   = var.pm_password
  target_node   = "raisin"
  template_name = "flatcar-production-qemu-3602.2.1"
  butane_conf   = "${path.module}/vm-configuration.bu.tftpl"
  name          = "flatcar-sample-container"
  vm_id         = 500
  networks      = [{ bridge = "vmbr0", tag = 109 }]
  tags          = ["sample", "flatcar"]
  vm_count      = 1
}
