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

locals {
  node_settings = {
    "manager-01" = { role = "manager", region = "ap-south", type = "g6-standard-2", vlan_ipam_address = "10.0.0.1/24" },
    "manager-02" = { role = "manager", region = "ap-south", type = "g6-standard-2", vlan_ipam_address = "10.0.0.2/24" },
    "manager-03" = { role = "manager", region = "ap-south", type = "g6-standard-2", vlan_ipam_address = "10.0.0.3/24" }

    #"worker-01" = { role = "worker", region = "ap-south", type = "g6-standard-2", vlan_ipam_address = "10.0.0.6/24" },
  }
}

resource "linode_instance" "nodes" {

  for_each = local.node_settings

  label  = each.key
  region = each.value.region
  type   = each.value.type
  tags   = [each.value.role]
  group  = "example"
  private_ip = true
  # # region = "eu-central"
  # #  curl https://api.linode.com/v4/linode/types | jq
  # #type            = "g6-standard-1" # Linode 2 GB
  # #type            = "g6-standard-2" # Linode 4 GB
  # type            = "g6-standard-4" # Linode 8 GB
}

resource "linode_instance_config" "node_config" {
  for_each = local.node_settings

  linode_id = linode_instance.nodes[each.key].id
  label     = "node-config"

  interface {
    purpose = "public"
  }

  interface {
    purpose      = "vlan"
    label        = "swarm-vlan"
    ipam_address = each.value.vlan_ipam_address
  }

  devices {
    sda { disk_id = linode_instance_disk.boot[each.key].id }
    sdb { disk_id = linode_instance_disk.swap[each.key].id }
    sdc { disk_id = linode_instance_disk.storage[each.key].id }
  }

  booted = true
}

resource "linode_instance_disk" "boot" {
  for_each = local.node_settings

  label     = "boot"
  linode_id = linode_instance.nodes[each.key].id
  size      = 30720

  image           = "linode/rocky8"
  root_pass       = var.root_pass
  authorized_keys = var.authorized_keys
}

resource "linode_instance_disk" "swap" {
  for_each = local.node_settings

  label      = "swap"
  linode_id  = linode_instance.nodes[each.key].id
  size       = 256
  filesystem = "swap"
}

resource "linode_instance_disk" "storage" {
  for_each = local.node_settings

  label      = "storage"
  linode_id  = linode_instance.nodes[each.key].id
  size       = linode_instance.nodes[each.key].specs.0.disk - 256 - 30720
  filesystem = "raw"
}


resource "linode_nodebalancer" "swarm_lb" {
    label = "swarm-lb"
    region = "ap-south"
    #client_conn_throttle = 60
}

resource "linode_nodebalancer_config" "swarm_lb_http_config" {
    nodebalancer_id = linode_nodebalancer.swarm_lb.id
    port = 80
    protocol = "tcp"
    check = "connection"
    check_attempts = 3
    check_timeout = 30
    algorithm = "roundrobin"
}

resource "linode_nodebalancer_config" "swarm_lb_https_config" {
    nodebalancer_id = linode_nodebalancer.swarm_lb.id
    port = 443
    protocol = "tcp"
    check = "connection"
    check_attempts = 3
    check_timeout = 30
    algorithm = "roundrobin"
}

resource "linode_nodebalancer_node" "swarm_lb_http_node" {
    for_each = local.node_settings

    nodebalancer_id = linode_nodebalancer.swarm_lb.id
    config_id = linode_nodebalancer_config.swarm_lb_http_config.id
    address = "${linode_instance.nodes[each.key].private_ip_address}:80"
    label = "swarm-lb-http-node"
    #weight = 50
}

resource "linode_nodebalancer_node" "swarm_lb_https_node" {
    for_each = local.node_settings

    nodebalancer_id = linode_nodebalancer.swarm_lb.id
    config_id = linode_nodebalancer_config.swarm_lb_https_config.id
    address = "${linode_instance.nodes[each.key].private_ip_address}:443"
    label = "swarm-lb-https-node"
    #weight = 50
}

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tftpl",
    {
      nodes = linode_instance.nodes
    }
  )
  filename = "../ansible/inventory.ini"
}
