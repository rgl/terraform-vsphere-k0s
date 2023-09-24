# see https://github.com/hashicorp/terraform
terraform {
  required_version = "1.5.7"
  required_providers {
    # see https://registry.terraform.io/providers/hashicorp/random
    random = {
      source  = "hashicorp/random"
      version = "3.5.1"
    }
    # see https://registry.terraform.io/providers/hashicorp/template
    template = {
      source  = "hashicorp/template"
      version = "2.2.0"
    }
    # see https://registry.terraform.io/providers/hashicorp/vsphere
    # see https://github.com/hashicorp/terraform-provider-vsphere
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "2.4.3"
    }
    # see https://registry.terraform.io/providers/alessiodionisi/k0s
    # see https://github.com/alessiodionisi/terraform-provider-k0s
    k0s = {
      source  = "alessiodionisi/k0s"
      version = "0.2.1"
    }
  }
}

variable "vsphere_user" {
  type    = string
  default = "administrator@vsphere.local"
}

variable "vsphere_password" {
  type      = string
  default   = "password"
  sensitive = true
}

variable "vsphere_server" {
  type    = string
  default = "vsphere.local"
}

variable "vsphere_datacenter" {
  type    = string
  default = "Datacenter"
}

variable "vsphere_compute_cluster" {
  type    = string
  default = "Cluster"
}

variable "vsphere_network" {
  type    = string
  default = "VM Network"
}

variable "vsphere_datastore" {
  type    = string
  default = "Datastore"
}

variable "vsphere_folder" {
  type    = string
  default = "example"
}

variable "vsphere_k0s_template" {
  type    = string
  default = "vagrant-templates/debian-12-amd64-vsphere"
}

provider "vsphere" {
  user                 = var.vsphere_user
  password             = var.vsphere_password
  vsphere_server       = var.vsphere_server
  allow_unverified_ssl = true
}

data "vsphere_datacenter" "datacenter" {
  name = var.vsphere_datacenter
}

data "vsphere_compute_cluster" "compute_cluster" {
  name          = var.vsphere_compute_cluster
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_datastore" "datastore" {
  name          = var.vsphere_datastore
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_network" "network" {
  name          = var.vsphere_network
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_virtual_machine" "k0s_template" {
  name          = var.vsphere_k0s_template
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

provider "k0s" {
}

variable "prefix" {
  type    = string
  default = "k0s"
}

variable "controller_count" {
  type    = number
  default = 1
  validation {
    condition     = var.controller_count >= 1
    error_message = "Must be 1 or more."
  }
}

variable "worker_count" {
  type    = number
  default = 1
  validation {
    condition     = var.worker_count >= 1
    error_message = "Must be 1 or more."
  }
}

variable "cluster_name" {
  description = "A name to provide for the k0s cluster"
  type        = string
  default     = "k0s"
}

locals {
  domain = "test"
  controller_nodes = [
    for i in range(var.controller_count) : {
      name = "c${i}"
      fqdn = "c${i}.${local.domain}"
    }
  ]
  worker_nodes = [
    for i in range(var.worker_count) : {
      name = "w${i}"
      fqdn = "w${i}.${local.domain}"
    }
  ]
}

# the controllers cloud-init cloud-config.
# NB this creates an iso image that will be used by the NoCloud cloud-init datasource.
# see journactl -u cloud-init
# see /run/cloud-init/*.log
# see less /usr/share/doc/cloud-init/examples/cloud-config.txt.gz
# see https://cloudinit.readthedocs.io/en/latest/topics/examples.html#disk-setup
# see https://www.terraform.io/docs/providers/template/d/cloudinit_config.html
# see https://www.terraform.io/docs/configuration/expressions.html#string-literals
# see https://cloudinit.readthedocs.io/en/latest/topics/examples.html#disk-setup
# see https://cloudinit.readthedocs.io/en/latest/topics/datasources/nocloud.html#datasource-nocloud
data "template_cloudinit_config" "controller" {
  count = var.controller_count
  part {
    content_type = "text/cloud-config"
    content      = <<-EOF
      #cloud-config
      fqdn: ${local.controller_nodes[count.index].fqdn}
      manage_etc_hosts: true
      users:
        - name: vagrant
          passwd: '$6$rounds=4096$NQ.EmIrGxn$rTvGsI3WIsix9TjWaDfKrt9tm3aa7SX7pzB.PSjbwtLbsplk1HsVzIrZbXwQNce6wmeJXhCq9YFJHDx9bXFHH.'
          lock_passwd: false
          ssh-authorized-keys:
            - ${jsonencode(trimspace(file("~/.ssh/id_rsa.pub")))}
      runcmd:
        - sed -i '/vagrant insecure public key/d' /home/vagrant/.ssh/authorized_keys
        # make sure the vagrant account is not expired.
        # NB this is needed when the base image expires the vagrant account.
        - usermod --expiredate '' vagrant
      EOF
  }
}

# the workes cloud-init cloud-config.
# NB this creates an iso image that will be used by the NoCloud cloud-init datasource.
# see journactl -u cloud-init
# see /run/cloud-init/*.log
# see less /usr/share/doc/cloud-init/examples/cloud-config.txt.gz
# see https://cloudinit.readthedocs.io/en/latest/topics/examples.html#disk-setup
# see https://www.terraform.io/docs/providers/template/d/cloudinit_config.html
# see https://www.terraform.io/docs/configuration/expressions.html#string-literals
# see https://cloudinit.readthedocs.io/en/latest/topics/examples.html#disk-setup
# see https://cloudinit.readthedocs.io/en/latest/topics/datasources/nocloud.html#datasource-nocloud
data "template_cloudinit_config" "worker" {
  count = var.worker_count
  part {
    content_type = "text/cloud-config"
    content      = <<-EOF
      #cloud-config
      fqdn: ${local.worker_nodes[count.index].fqdn}
      manage_etc_hosts: true
      users:
        - name: vagrant
          passwd: '$6$rounds=4096$NQ.EmIrGxn$rTvGsI3WIsix9TjWaDfKrt9tm3aa7SX7pzB.PSjbwtLbsplk1HsVzIrZbXwQNce6wmeJXhCq9YFJHDx9bXFHH.'
          lock_passwd: false
          ssh-authorized-keys:
            - ${jsonencode(trimspace(file("~/.ssh/id_rsa.pub")))}
      runcmd:
        - sed -i '/vagrant insecure public key/d' /home/vagrant/.ssh/authorized_keys
        # make sure the vagrant account is not expired.
        # NB this is needed when the base image expires the vagrant account.
        - usermod --expiredate '' vagrant
      EOF
  }
}

resource "vsphere_folder" "k0s" {
  path          = var.vsphere_folder
  type          = "vm"
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

# see https://www.terraform.io/docs/providers/vsphere/r/virtual_machine.html
resource "vsphere_virtual_machine" "controller" {
  count                = var.controller_count
  folder               = vsphere_folder.k0s.path
  name                 = "${var.prefix}-${local.controller_nodes[count.index].name}"
  guest_id             = data.vsphere_virtual_machine.k0s_template.guest_id
  firmware             = data.vsphere_virtual_machine.k0s_template.firmware
  num_cpus             = 4
  num_cores_per_socket = 4
  memory               = 2 * 1024
  nested_hv_enabled    = true
  vvtd_enabled         = true
  enable_disk_uuid     = true # NB the VM must have disk.EnableUUID=1 for, e.g., k8s persistent storage.
  resource_pool_id     = data.vsphere_compute_cluster.compute_cluster.resource_pool_id
  datastore_id         = data.vsphere_datastore.datastore.id
  scsi_type            = data.vsphere_virtual_machine.k0s_template.scsi_type
  disk {
    unit_number      = 0
    label            = "os"
    size             = max(data.vsphere_virtual_machine.k0s_template.disks[0].size, 40) # [GiB]
    eagerly_scrub    = data.vsphere_virtual_machine.k0s_template.disks[0].eagerly_scrub
    thin_provisioned = data.vsphere_virtual_machine.k0s_template.disks[0].thin_provisioned
  }
  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = data.vsphere_virtual_machine.k0s_template.network_interface_types[0]
  }
  clone {
    template_uuid = data.vsphere_virtual_machine.k0s_template.id
  }
  # NB this extra_config data ends-up inside the VM .vmx file and will be
  #    exposed by cloud-init-vmware-guestinfo as a cloud-init datasource.
  extra_config = {
    "guestinfo.userdata"          = data.template_cloudinit_config.controller[count.index].rendered
    "guestinfo.userdata.encoding" = "gzip+base64"
  }
  provisioner "remote-exec" {
    inline = [
      "set -eux",
      "cloud-init status --long --wait",
    ]
    connection {
      type        = "ssh"
      user        = "vagrant"
      host        = self.default_ip_address
      private_key = file("~/.ssh/id_rsa")
    }
  }
  lifecycle {
    ignore_changes = [
      # TODO open issue about these.
      ept_rvi_mode,
      hv_mode,
    ]
  }
}

# see https://www.terraform.io/docs/providers/vsphere/r/virtual_machine.html
resource "vsphere_virtual_machine" "worker" {
  count                = var.worker_count
  folder               = vsphere_folder.k0s.path
  name                 = "${var.prefix}-${local.worker_nodes[count.index].name}"
  guest_id             = data.vsphere_virtual_machine.k0s_template.guest_id
  firmware             = data.vsphere_virtual_machine.k0s_template.firmware
  num_cpus             = 4
  num_cores_per_socket = 4
  memory               = 8 * 1024
  nested_hv_enabled    = true
  vvtd_enabled         = true
  enable_disk_uuid     = true # NB the VM must have disk.EnableUUID=1 for, e.g., k8s persistent storage.
  resource_pool_id     = data.vsphere_compute_cluster.compute_cluster.resource_pool_id
  datastore_id         = data.vsphere_datastore.datastore.id
  scsi_type            = data.vsphere_virtual_machine.k0s_template.scsi_type
  disk {
    unit_number      = 0
    label            = "os"
    size             = max(data.vsphere_virtual_machine.k0s_template.disks[0].size, 40) # [GiB]
    eagerly_scrub    = data.vsphere_virtual_machine.k0s_template.disks[0].eagerly_scrub
    thin_provisioned = data.vsphere_virtual_machine.k0s_template.disks[0].thin_provisioned
  }
  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = data.vsphere_virtual_machine.k0s_template.network_interface_types[0]
  }
  clone {
    template_uuid = data.vsphere_virtual_machine.k0s_template.id
  }
  # NB this extra_config data ends-up inside the VM .vmx file and will be
  #    exposed by cloud-init-vmware-guestinfo as a cloud-init datasource.
  extra_config = {
    "guestinfo.userdata"          = data.template_cloudinit_config.worker[count.index].rendered
    "guestinfo.userdata.encoding" = "gzip+base64"
  }
  provisioner "remote-exec" {
    inline = [
      "set -eux",
      "cloud-init status --long --wait",
    ]
    connection {
      type        = "ssh"
      user        = "vagrant"
      host        = self.default_ip_address
      private_key = file("~/.ssh/id_rsa")
    }
  }
  lifecycle {
    ignore_changes = [
      # TODO open issue about these.
      ept_rvi_mode,
      hv_mode,
    ]
  }
}

resource "k0s_cluster" "k0s" {
  name    = var.cluster_name
  version = "v1.26.8+k0s.0" # see https://github.com/k0sproject/k0s/releases
  depends_on = [
    vsphere_virtual_machine.controller,
    vsphere_virtual_machine.worker,
  ]
  hosts = concat(
    [
      for n in vsphere_virtual_machine.controller : {
        role = "controller+worker"
        ssh = {
          address  = n.default_ip_address
          port     = 22
          user     = "vagrant"
          key_path = "~/.ssh/id_rsa"
        }
      }
    ],
    [
      for n in vsphere_virtual_machine.worker : {
        role = "worker"
        ssh = {
          address  = n.default_ip_address
          port     = 22
          user     = "vagrant"
          key_path = "~/.ssh/id_rsa"
        }
      }
    ]
  )
  config = yamlencode({
    spec = {
      telemetry = {
        enabled = false
      }
    }
  })
}

output "kubeconfig" {
  sensitive = true
  value     = k0s_cluster.k0s.kubeconfig
}

output "controllers" {
  value = [for node in vsphere_virtual_machine.controller : node.default_ip_address]
}

output "workers" {
  value = [for node in vsphere_virtual_machine.worker : node.default_ip_address]
}
