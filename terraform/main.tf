terraform {
  required_providers {
    linode = {
      source  = "linode/linode"
      version = "1.29.4"
    }
  }
}

provider "linode" {
  token = var.linode_token
}

resource "linode_instance" "managers" {
  count = 1
  image  = "linode/rocky9"
  label  = "swarm-manager-${format("%02s", count.index)}"
  group  = "example"
  region = "ap-south"
  # region = "eu-central"
  type            = "g6-standard-1"
  authorized_keys = var.authorized_keys
  root_pass       = var.root_pass

  interface {
    purpose = "public"
  }

  interface {
    purpose = "vlan"
    label = "swarm-vlan"
    ipam_address = "10.0.0.${1 + count.index}/24"
  }
}

resource "linode_instance" "workers" {
  count = 2
  image  = "linode/rocky9"
  label  = "swarm-worker-${format("%02s", count.index)}"
  group  = "example"
  region = "ap-south"
  # region = "eu-central"
  type            = "g6-standard-1"
  authorized_keys = var.authorized_keys
  root_pass       = var.root_pass

  interface {
    purpose = "public"
  }

  interface {
    purpose = "vlan"
    label = "swarm-vlan"
    ipam_address = "10.0.0.${10 + count.index}/24"
  }
}

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tftpl",
    {
      manager_addresses = linode_instance.managers[*].ip_address
      manager_labels = linode_instance.managers[*].label
      worker_addresses = linode_instance.workers[*].ip_address
      worker_labels = linode_instance.workers[*].label
    }
  )
  filename = "../ansible/inventory.ini"
}
