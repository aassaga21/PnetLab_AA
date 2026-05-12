###############################################################
# PNETLab VM - Infomaniak Public Cloud (OpenStack)
# Région : dc3-a
###############################################################

terraform {
  required_version = ">= 1.3.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.54"
    }
  }
}

# ---------------------------------------------------------------
# Provider OpenStack (Infomaniak Public Cloud)
# ---------------------------------------------------------------
provider "openstack" {
  auth_url    = var.auth_url
  tenant_name = var.project_name
  user_name   = var.username
  password    = var.password
  region      = var.region
}

# ---------------------------------------------------------------
# Image personnalisée PNETLab (upload depuis QCOW2)
# ---------------------------------------------------------------
resource "openstack_images_image_v2" "pnetlab" {
  name             = "PNETLab-4.2.10"
  container_format = "bare"
  disk_format      = "qcow2"
  visibility       = "private"
  local_file_path  = var.pnetlab_image_path

  properties = {
    os_type              = "linux"
    os_distro            = "ubuntu"
    hw_vif_model         = "virtio"
    hw_disk_bus          = "virtio"
    hw_scsi_model        = "virtio-scsi"
    hw_cpu_policy        = "dedicated"
    hw_cpu_thread_policy = "prefer"
    hypervisor_type      = "kvm"
  }
}

# ---------------------------------------------------------------
# Réseau interne dédié PNETLab
# ---------------------------------------------------------------
resource "openstack_networking_network_v2" "pnetlab_net" {
  name           = "net-pnetlab"
  admin_state_up = true
}

resource "openstack_networking_subnet_v2" "pnetlab_subnet" {
  name            = "subnet-pnetlab"
  network_id      = openstack_networking_network_v2.pnetlab_net.id
  cidr            = "192.168.100.0/24"
  ip_version      = 4
  dns_nameservers = ["84.16.67.69", "84.16.67.70"]
}

# Routeur pour accès Internet (NAT)
resource "openstack_networking_router_v2" "pnetlab_router" {
  name                = "router-pnetlab"
  admin_state_up      = true
  external_network_id = var.external_network_id
}

resource "openstack_networking_router_interface_v2" "pnetlab_router_iface" {
  router_id = openstack_networking_router_v2.pnetlab_router.id
  subnet_id = openstack_networking_subnet_v2.pnetlab_subnet.id
}

# ---------------------------------------------------------------
# Groupe de sécurité PNETLab
# ---------------------------------------------------------------
resource "openstack_networking_secgroup_v2" "pnetlab_sg" {
  name        = "sg-pnetlab"
  description = "Security group pour VM PNETLab"
}

# SSH
resource "openstack_networking_secgroup_rule_v2" "ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.admin_cidr
  security_group_id = openstack_networking_secgroup_v2.pnetlab_sg.id
}

# HTTP (interface web PNETLab)
resource "openstack_networking_secgroup_rule_v2" "http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = var.admin_cidr
  security_group_id = openstack_networking_secgroup_v2.pnetlab_sg.id
}

# HTTPS
resource "openstack_networking_secgroup_rule_v2" "https" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = var.admin_cidr
  security_group_id = openstack_networking_secgroup_v2.pnetlab_sg.id
}

# Telnet (console nœuds réseau PNETLab : ports 32xxx)
resource "openstack_networking_secgroup_rule_v2" "telnet_nodes" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 32000
  port_range_max    = 40000
  remote_ip_prefix  = var.admin_cidr
  security_group_id = openstack_networking_secgroup_v2.pnetlab_sg.id
}

# VNC (accès console noeuds)
resource "openstack_networking_secgroup_rule_v2" "vnc" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 5900
  port_range_max    = 5999
  remote_ip_prefix  = var.admin_cidr
  security_group_id = openstack_networking_secgroup_v2.pnetlab_sg.id
}

# ---------------------------------------------------------------
# Paire de clés SSH
# ---------------------------------------------------------------
resource "openstack_compute_keypair_v2" "pnetlab_key" {
  name       = "keypair-pnetlab"
  public_key = file(var.ssh_public_key_path)
}

# ---------------------------------------------------------------
# Volume racine persistant (200 Go) - type CEPH_1_perf1 (Infomaniak)
# ---------------------------------------------------------------
resource "openstack_blockstorage_volume_v3" "pnetlab_root" {
  name              = "vol-pnetlab-root"
  size              = 200
  image_id          = openstack_images_image_v2.pnetlab.id
  volume_type       = "CEPH_1_perf1"
  availability_zone = var.availability_zone

  metadata = {
    purpose = "pnetlab-root-disk"
  }
}

# ---------------------------------------------------------------
# Instance PNETLab
# Flavor choisi : a8-ram32-disk50-perf1 (8 vCPU / 32 Go RAM)
# Compatible avec les quotas disponibles
# ---------------------------------------------------------------
resource "openstack_compute_instance_v2" "pnetlab" {
  name              = "vm-pnetlab-01"
  flavor_id         = var.flavor_id
  key_pair          = openstack_compute_keypair_v2.pnetlab_key.name
  availability_zone = var.availability_zone

  # Boot depuis le volume persistant
  block_device {
    uuid                  = openstack_blockstorage_volume_v3.pnetlab_root.id
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = 0
    delete_on_termination = false
  }

  network {
    uuid = openstack_networking_network_v2.pnetlab_net.id
  }

  security_groups = [openstack_networking_secgroup_v2.pnetlab_sg.name]

  user_data = base64encode(templatefile("${path.module}/userdata.sh", {
    admin_password = var.pnetlab_admin_password
  }))

  metadata = {
    environment = "lab"
    tool        = "pnetlab"
    managed_by  = "terraform"
  }

  depends_on = [
    openstack_networking_router_interface_v2.pnetlab_router_iface
  ]
}

# ---------------------------------------------------------------
# IP flottante (accès externe)
# ---------------------------------------------------------------
resource "openstack_networking_floatingip_v2" "pnetlab_fip" {
  pool = var.floating_ip_pool
}

# Utilisation de la ressource non-dépréciée
resource "openstack_networking_floatingip_associate_v2" "pnetlab_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.pnetlab_fip.address
  port_id     = openstack_compute_instance_v2.pnetlab.network[0].port
}
