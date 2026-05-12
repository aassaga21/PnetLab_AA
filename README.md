# PNETLab sur Infomaniak Public Cloud

## Par : Alexandra ASSAGA
## Date : 12.05.2026

---

## Table des matières

1. [Introduction](#introduction)
2. [Objectifs](#objectifs)
3. [Architecture déployée](#architecture-déployée)
4. [Ressources créées](#ressources-créées)
5. [Prérequis](#prérequis)
6. [Fichiers Terraform](#fichiers-terraform)
7. [Déploiement](#déploiement)
8. [Accès à PNETLab](#accès-à-pnetlab)
9. [Configuration initiale](#configuration-initiale-wizard-ssh)
10. [Ajout d'images réseau](#ajout-dimages-réseau-ishare2)
11. [Problème connu : Nested KVM](#problème-connu--nested-kvm)
12. [Capacités de la VM](#capacités-de-la-vm-en-termes-de-nœuds-pnetlab)
13. [Destruction de l'infrastructure](#destruction-de-linfrastructure)
14. [Conclusion](#conclusion)

---

## Introduction

Ce projet explique le déploiement automatisé d'une instance **PNETLab** (Packet Network Emulator Lab) sur le **cloud public Infomaniak**, en utilisant **Terraform** comme outil d'Infrastructure as Code (IaC).

PNETLab est une plateforme d'émulation réseau multi-vendeurs permettant de simuler des équipements réels tels que des routeurs Cisco, des firewalls Palo Alto, FortiGate, des switches Juniper, etc. Elle est largement utilisée pour la formation, la préparation aux certifications réseau (CCNA, CCNP, CCIE, NSE, PCNSE) et pour les tests d'infrastructure.

Le cloud public Infomaniak repose sur **OpenStack**, une plateforme open source de cloud computing. Terraform, via le provider OpenStack, permet de provisionner l'ensemble des ressources nécessaires (VM, réseau, volumes, groupes de sécurité, IP flottantes) de manière déclarative et reproductible.

L'image PNETLab officielle, disponible au format OVA, a été convertie en QCOW2 (format natif OpenStack) puis uploadée comme image personnalisée sur Infomaniak avant d'être utilisée pour créer la VM.

---

## Objectifs

- Déployer une VM PNETLab fonctionnelle sur Infomaniak Public Cloud via Terraform
- Automatiser la création de toutes les ressources réseau (réseau privé, routeur, groupe de sécurité, IP flottante)
- Uploader une image PNETLab personnalisée au format QCOW2
- Configurer un volume persistant pour que les labs survivent aux redémarrages
- Accéder à l'interface web PNETLab depuis n'importe quel navigateur
- Installer et configurer ishare2 pour télécharger des images d'équipements réseau
- Activer la virtualisation imbriquée (Nested KVM) pour faire tourner les nœuds QEMU lourds

---

## Architecture déployée

```
Internet
   │
   │ IP flottante publique (83.228.248.244)
   ▼
[routeur OpenStack — router-pnetlab]
   │
   │ net-pnetlab — 192.168.100.0/24
   ▼
[VM PNETLab — vm-pnetlab-01]
  8 vCPU | 32 Go RAM | 200 Go (CEPH_1_perf1)
  sg-pnetlab : SSH(22) / HTTP(80) / HTTPS(443)
              Telnet noeuds(32000-40000) / VNC(5900-5999)
  Nested KVM en attente d'activation (support Infomaniak)
```

---

## Ressources créées

| Ressource | Valeur |
|-----------|--------|
| Instance | `vm-pnetlab-01` |
| Instance ID | `3b50b17d-681c-4a8a-bbdb-0c14683eab1c` |
| Flavor | `a8-ram32-disk50-perf1` |
| vCPUs | 8 |
| RAM | 32 Go |
| Disque | 50 Go (flavor) + 200 Go (volume CEPH_1_perf1) |
| IP flottante | `83.228.248.244` |
| IP privée | `192.168.100.203` |
| Réseau | `net-pnetlab` — 192.168.100.0/24 |
| Zone | `az-1` |
| Région | `dc4-a` |
| Projet | `PCP-LPGJL2D` |
| Image | `PNETLab-4.2.10` (QCOW2 converti depuis OVA) |
| Interface web | `http://83.228.248.244` |

---

## Prérequis

### 1. Outils requis

```bash
# Installation de Terraform
wget https://releases.hashicorp.com/terraform/1.9.8/terraform_1.9.8_linux_amd64.zip
unzip terraform_1.9.8_linux_amd64.zip
sudo mv terraform /usr/local/bin/
terraform version
```

![image](https://hackmd.io/_uploads/ByYH-Cg1Gx.png)
![image](https://hackmd.io/_uploads/BJ_8b0gkMg.png)
![image](https://hackmd.io/_uploads/H1UvbRlyMe.png)

> ### Sur Ubuntu 25.04 (Resolute), le repo HashiCorp APT n'est pas supporté
![image](https://hackmd.io/_uploads/BJGj-0l1zl.png)
![image](https://hackmd.io/_uploads/rJP0-0xJze.png)

> ### Terraform >= 1.9
> ### Installer via binaire direct :
![image](https://hackmd.io/_uploads/SJSkGAlyze.png)
![image](https://hackmd.io/_uploads/SyCtXAekMx.png)
![image](https://hackmd.io/_uploads/BJgsXAx1Gl.png)
![image](https://hackmd.io/_uploads/rkk2QCeJMe.png)

```bash
# OpenStack CLI
sudo apt install python3-pip
sudo apt install python3-openstackclient -y
openstack --version
```

![image](https://hackmd.io/_uploads/rJbkHRx1zl.png)
![image](https://hackmd.io/_uploads/Byn1HCe1ze.png)
![image](https://hackmd.io/_uploads/SyLerAxkGg.png)
![image](https://hackmd.io/_uploads/ByTxSRgyzx.png)
![image](https://hackmd.io/_uploads/B1UWBRxkMl.png)
![image](https://hackmd.io/_uploads/rkBzSAxyGl.png)

```bash
# QEMU tools (pour convertir l'image OVA → QCOW2)
sudo apt-get qemu-system
qemu-img --version
# qemu-img version 10.2.1
```
Télécharger qemu depuis [Download QEMU](https://www.qemu.org/download/#linux)
![image](https://hackmd.io/_uploads/H17RQAe1Gl.png)
![image](https://hackmd.io/_uploads/H1GEEAe1Mx.png)
![image](https://hackmd.io/_uploads/HyiNEAlkMg.png)
![image](https://hackmd.io/_uploads/SkUr4Agyzg.png)

### 2. Préparer l'image PNETLab

Télécharger l'OVA depuis https://pnetlab.com/pages/download (version 4.2.10)
![image](https://hackmd.io/_uploads/BkwDSAxyGl.png)
![image](https://hackmd.io/_uploads/SyPdS0gJfg.png)
![image](https://hackmd.io/_uploads/BkOYSRgkfe.png)
![image](https://hackmd.io/_uploads/rJrcrClkGx.png)
![image](https://hackmd.io/_uploads/rk-orCl1zx.png)

```bash
# Se placer dans le dossier Downloads
cd /mnt/c/Users/<user>/Downloads

# Extraire le VMDK depuis l'OVA
tar -xvf PNET_4.2.10.ova
# Produit : PNET_4.2.10.ovf, PNET_4.2.10.mf, PNET_4.2.10-disk1.vmdk

# Convertir en QCOW2 (format OpenStack)
qemu-img convert -f vmdk -O qcow2 PNET_4.2.10-disk1.vmdk pnetlab.qcow2

# Vérifier
qemu-img info pnetlab.qcow2
# virtual size: 100 GiB
# disk size: 5.56 GiB
# file format: qcow2
```
![image](https://hackmd.io/_uploads/rJ0irClkfe.png)
![image](https://hackmd.io/_uploads/Hy_nrCeJMe.png)

### 3. Récupérer les credentials OpenStack

Depuis Horizon → **Accès API** → **Télécharger le fichier RC OpenStack v3**

```bash
cat > ~/openstack-rc.sh << 'EOF'
export OS_AUTH_URL="https://api.pub1.infomaniak.cloud/identity/v3"
export OS_PROJECT_NAME="PCP-LPGJL2D"
export OS_USERNAME="PCU-LPGJL2D"
export OS_USER_DOMAIN_NAME="Default"
export OS_PROJECT_DOMAIN_NAME="Default"
export OS_REGION_NAME="dc4-a"
export OS_IDENTITY_API_VERSION="3"
export OS_INTERFACE="public"
export OS_PASSWORD="VOTRE_MOT_DE_PASSE"
EOF

source ~/openstack-rc.sh
```
![image](https://hackmd.io/_uploads/BkPSS0xyMl.png)
![image](https://hackmd.io/_uploads/HymLBClyMl.png)

### 4. Vérifier les ressources disponibles

```bash
# Réseau externe
openstack network list --external
# → ext-floating1 : 34a684b8-2889-4950-b08e-c33b3954a307

# Zones de disponibilité
openstack availability zone list
# → az-1, az-2, az-3

# Flavors disponibles
openstack flavor list
# → a8-ram32-disk50-perf1 | ID : 3a4c0e4f-b272-4aa0-959a-eb4088c87b6d

# Types de volumes
openstack volume type list
# → CEPH_1_perf1 (seul type disponible)
```
![image](https://hackmd.io/_uploads/HJspIClJzl.png)
![image](https://hackmd.io/_uploads/BJHFL0xJMe.png)
![image](https://hackmd.io/_uploads/S1XDLRlyGl.png)
![image](https://hackmd.io/_uploads/rk-OU0xyGe.png)
![image](https://hackmd.io/_uploads/HkqrU0lJze.png)

### 5. Générer une clé SSH dédiée

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa_pnetlab -C "pnetlab-infomaniak"
```
![image](https://hackmd.io/_uploads/r17x8Agyfl.png)
![image](https://hackmd.io/_uploads/HkgzUAgyze.png)

---

## Fichiers Terraform

Le projet est composé de 5 fichiers :

```
pnetlab-infomaniak/
├── .git                   # Ressources principales
├── main.tf                   # Ressources principales
├── variables.tf              # Déclaration des variables
├── outputs.tf                # Sorties (IP, URL, etc.)
├── userdata.sh               # Script post-boot cloud-init
├── terraform.tfvars.example  # Exemple de configuration
└── .gitignore                # Exclut terraform.tfvars et .terraform/
```
![image](https://hackmd.io/_uploads/SJayvCxkMl.png)

---

### main.tf

Ce fichier définit toutes les ressources OpenStack à créer : provider, image, réseau, groupe de sécurité, keypair, volume, instance et IP flottante.

```hcl
###############################################################
# PNETLab VM - Infomaniak Public Cloud (OpenStack)
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

# Provider OpenStack
provider "openstack" {
  auth_url    = var.auth_url
  tenant_name = var.project_name
  user_name   = var.username
  password    = var.password
  region      = var.region
}

# Upload de l'image PNETLab QCOW2
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

# Réseau interne dédié
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

# Routeur avec accès Internet
resource "openstack_networking_router_v2" "pnetlab_router" {
  name                = "router-pnetlab"
  admin_state_up      = true
  external_network_id = var.external_network_id
}

resource "openstack_networking_router_interface_v2" "pnetlab_router_iface" {
  router_id = openstack_networking_router_v2.pnetlab_router.id
  subnet_id = openstack_networking_subnet_v2.pnetlab_subnet.id
}

# Groupe de sécurité
resource "openstack_networking_secgroup_v2" "pnetlab_sg" {
  name        = "sg-pnetlab"
  description = "Security group pour VM PNETLab"
}

resource "openstack_networking_secgroup_rule_v2" "ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.admin_cidr
  security_group_id = openstack_networking_secgroup_v2.pnetlab_sg.id
}

resource "openstack_networking_secgroup_rule_v2" "http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = var.admin_cidr
  security_group_id = openstack_networking_secgroup_v2.pnetlab_sg.id
}

resource "openstack_networking_secgroup_rule_v2" "https" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = var.admin_cidr
  security_group_id = openstack_networking_secgroup_v2.pnetlab_sg.id
}

resource "openstack_networking_secgroup_rule_v2" "telnet_nodes" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 32000
  port_range_max    = 40000
  remote_ip_prefix  = var.admin_cidr
  security_group_id = openstack_networking_secgroup_v2.pnetlab_sg.id
}

resource "openstack_networking_secgroup_rule_v2" "vnc" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 5900
  port_range_max    = 5999
  remote_ip_prefix  = var.admin_cidr
  security_group_id = openstack_networking_secgroup_v2.pnetlab_sg.id
}

# Paire de clés SSH
resource "openstack_compute_keypair_v2" "pnetlab_key" {
  name       = "keypair-pnetlab"
  public_key = file(var.ssh_public_key_path)
}

# Volume persistant 200 Go (CEPH_1_perf1 — seul type Infomaniak)
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

# Instance PNETLab (flavor a8-ram32-disk50-perf1)
resource "openstack_compute_instance_v2" "pnetlab" {
  name              = "vm-pnetlab-01"
  flavor_id         = var.flavor_id
  key_pair          = openstack_compute_keypair_v2.pnetlab_key.name
  availability_zone = var.availability_zone

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

# IP flottante publique
resource "openstack_networking_floatingip_v2" "pnetlab_fip" {
  pool = var.floating_ip_pool
}

resource "openstack_networking_floatingip_associate_v2" "pnetlab_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.pnetlab_fip.address
  port_id     = openstack_compute_instance_v2.pnetlab.network[0].port
}
```
![image](https://hackmd.io/_uploads/SylHGkbJMe.png)
![image](https://hackmd.io/_uploads/H1ePw0lyMl.png)
![image](https://hackmd.io/_uploads/rJcXx1-yMl.png)
![image](https://hackmd.io/_uploads/rJ3SxJZ1fg.png)
![image](https://hackmd.io/_uploads/rkhhWkZJMx.png)
![image](https://hackmd.io/_uploads/B1z-fk-Jzl.png)
![image](https://hackmd.io/_uploads/r13GG1Z1zg.png)
![image](https://hackmd.io/_uploads/rJRmGkWkMg.png)

---

### variables.tf

Ce fichier déclare toutes les variables utilisées par `main.tf`, avec leurs types, descriptions et valeurs par défaut.

```hcl
variable "auth_url" {
  description = "URL d'authentification Keystone Infomaniak"
  type        = string
  default     = "https://api.pub1.infomaniak.cloud/identity/v3"
}

variable "project_name" {
  description = "Nom du projet OpenStack (ex: PCP-LPGJL2D)"
  type        = string
}

variable "username" {
  description = "Nom d'utilisateur OpenStack (ex: PCU-LPGJL2D)"
  type        = string
}

variable "password" {
  description = "Mot de passe OpenStack"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "Région Infomaniak"
  type        = string
  default     = "dc4-a"
}

variable "pnetlab_image_path" {
  description = "Chemin local vers l'image QCOW2 de PNETLab"
  type        = string
  default     = "/mnt/c/Users/alexa/Downloads/pnetlab.qcow2"
}

variable "flavor_id" {
  description = "ID du flavor Infomaniak (8 vCPU / 32 Go RAM)"
  type        = string
  # a8-ram32-disk50-perf1
  default     = "3a4c0e4f-b272-4aa0-959a-eb4088c87b6d"
}

variable "external_network_id" {
  description = "ID du réseau externe Infomaniak"
  type        = string
  default     = "34a684b8-2889-4950-b08e-c33b3954a307"
}

variable "floating_ip_pool" {
  description = "Pool d'IP flottantes Infomaniak"
  type        = string
  default     = "ext-floating1"
}

variable "availability_zone" {
  description = "Zone de disponibilité"
  type        = string
  default     = "az-1"
}

variable "admin_cidr" {
  description = "CIDR autorisé à accéder à PNETLab"
  type        = string
  default     = "0.0.0.0/0"
}

variable "ssh_public_key_path" {
  description = "Chemin vers la clé publique SSH"
  type        = string
  default     = "~/.ssh/id_rsa_pnetlab.pub"
}

variable "pnetlab_admin_password" {
  description = "Mot de passe admin interface web PNETLab"
  type        = string
  sensitive   = true
  default     = "PnetLab@2025!"
}
```
![image](https://hackmd.io/_uploads/Bk6Czk-1Ml.png)
![image](https://hackmd.io/_uploads/B175zkZkGx.png)
![image](https://hackmd.io/_uploads/BkOsfJZyze.png)
![image](https://hackmd.io/_uploads/S1_3fJWJzx.png)

---

### outputs.tf

Ce fichier définit les sorties affichées après le `terraform apply`, permettant d'accéder directement aux informations importantes de la VM.

```hcl
output "pnetlab_floating_ip" {
  description = "IP publique pour accéder à PNETLab"
  value       = openstack_networking_floatingip_v2.pnetlab_fip.address
}

output "pnetlab_web_url" {
  description = "URL de l'interface web PNETLab"
  value       = "http://${openstack_networking_floatingip_v2.pnetlab_fip.address}"
}

output "pnetlab_ssh_command" {
  description = "Commande SSH pour se connecter à la VM"
  value       = "ssh -i ~/.ssh/id_rsa_pnetlab root@${openstack_networking_floatingip_v2.pnetlab_fip.address}"
}

output "pnetlab_instance_id" {
  description = "ID de l'instance OpenStack"
  value       = openstack_compute_instance_v2.pnetlab.id
}

output "pnetlab_private_ip" {
  description = "IP privée de la VM"
  value       = openstack_compute_instance_v2.pnetlab.access_ip_v4
}

output "image_id" {
  description = "ID de l'image PNETLab uploadée"
  value       = openstack_images_image_v2.pnetlab.id
}
```
![image](https://hackmd.io/_uploads/BJV-Fy-JMl.png)
![image](https://hackmd.io/_uploads/rJL24J-JGx.png)

---

### userdata.sh

Script cloud-init exécuté automatiquement au premier démarrage de la VM. Il configure le système, active le Nested KVM, optimise le réseau et initialise PNETLab.

```bash
#!/bin/bash
###############################################################
# userdata.sh - Post-configuration PNETLab au 1er boot
# Exécuté automatiquement par cloud-init
###############################################################

set -euo pipefail
exec > /var/log/pnetlab-init.log 2>&1

echo "=== [PNETLab Init] Démarrage $(date) ==="

# 1. Attendre que le réseau soit disponible
for i in {1..30}; do
  ping -c1 -W2 8.8.8.8 &>/dev/null && break
  echo "Attente réseau... ($i/30)"
  sleep 5
done

# 2. Mise à jour système
apt-get update -qq
apt-get upgrade -y -qq

# 3. Activer la virtualisation imbriquée (nested KVM)
modprobe kvm_intel nested=1 || modprobe kvm_amd nested=1 || true

cat > /etc/modprobe.d/kvm-nested.conf << 'EOF'
options kvm_intel nested=1
options kvm_amd nested=1
EOF

# 4. Optimisations réseau
cat >> /etc/sysctl.conf << 'EOF'
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
vm.swappiness = 10
EOF
sysctl -p

# 5. Hugepages
echo "vm.nr_hugepages = 1024" >> /etc/sysctl.conf
sysctl -w vm.nr_hugepages=1024

# 6. Changer le mot de passe admin PNETLab
for i in {1..60}; do
  systemctl is-active apache2 &>/dev/null && \
  systemctl is-active mysql &>/dev/null && break
  sleep 10
done

if systemctl is-active mysql &>/dev/null; then
  HASHED_PWD=$(echo -n "${admin_password}" | md5sum | cut -d' ' -f1)
  mysql -u root pnetlab -e \
    "UPDATE users SET password='$HASHED_PWD' WHERE username='admin';" 2>/dev/null || true
fi

# 7. Fix permissions PNETLab
if [ -f /opt/unetlab/html/includes/init.php ]; then
  /opt/unetlab/html/includes/init.php fix 2>/dev/null || true
fi

# 8. Activer les services au démarrage
systemctl enable apache2 mysql || true

echo "=== [PNETLab Init] Terminé $(date) ==="
echo "=== Accès web : http://$(curl -s ifconfig.me) ==="
```
![image](https://hackmd.io/_uploads/r1zeqybJMg.png)
![image](https://hackmd.io/_uploads/rkO7F1-kMg.png)
![image](https://hackmd.io/_uploads/rJStYk-yfe.png)
![image](https://hackmd.io/_uploads/B1T2tJWkMl.png)
![image](https://hackmd.io/_uploads/rJhpty-yzl.png)

---

### terraform.tfvars.example

Fichier modèle à copier en `terraform.tfvars` et remplir avec vos valeurs réelles.

```hcl
project_name           = "VOTRE_NOM_PROJET"
username               = "VOTRE_USERNAME"
password               = "VOTRE_MOT_DE_PASSE"
region                 = "VOTRE_REGION"
pnetlab_image_path     = "/mnt/c/Users/VOTRE_NOM/Downloads/pnetlab.qcow2"
external_network_id    = "34a684b8-2889-4950-b08e-c33b3954a307"
floating_ip_pool       = "ext-floating1"
availability_zone      = "az-1"
admin_cidr             = "0.0.0.0/0"
ssh_public_key_path    = "~/.ssh/id_rsa_pnetlab.pub"
pnetlab_admin_password = "VOTRE_MOT_DE_PASSE"
```

> Ne jamais commiter `terraform.tfvars` dans Git — il contient vos mots de passe.

---

## Déploiement

```bash
# 1. Se placer dans le répertoire
cd /mnt/c/git-lab-cloud/pnetlab-infomaniak

# 2. Configurer les variables
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars

# 3. Initialiser Terraform
terraform init

# 4. Vérifier le plan
terraform plan

# 5. Déployer
terraform apply -auto-approve
# ⏱ L'upload de l'image QCOW2 prend ~10-15 min (5.56 Go)
```
![image](https://hackmd.io/_uploads/rJpDcyb1Me.png)
![image](https://hackmd.io/_uploads/HySK5J-yfe.png)
![image](https://hackmd.io/_uploads/BJuq5yZJGx.png)
![image](https://hackmd.io/_uploads/ryZiqkb1zg.png)

> Voici 4 Problèmes rencontrés lors du déploiement de mon instance
![image](https://hackmd.io/_uploads/rJ-eo1b1zg.png)
![image](https://hackmd.io/_uploads/SktZoJW1Me.png)

> Après la résolution des problèmes, relancez la commande terraform apply -auto-approve pour terminer le déploiement

![image](https://hackmd.io/_uploads/Skd0iy-kGe.png)
![image](https://hackmd.io/_uploads/By87oyWyMx.png)
![image](https://hackmd.io/_uploads/Sk6XjJ-1Me.png)

### Résultat obtenu

```
Outputs:
pnetlab_floating_ip  = "83.228.248.244"
pnetlab_web_url      = "http://83.228.248.244"
pnetlab_ssh_command  = "ssh -i ~/.ssh/id_rsa_pnetlab root@83.228.248.244"
pnetlab_private_ip   = "192.168.100.203"
image_id             = "c1ec55d2-6136-4a27-ba1e-c728fa11e34b"
```

![image](https://hackmd.io/_uploads/rJ8Lhk-yfx.png)
![image](https://hackmd.io/_uploads/ryaNnyWyzg.png)
![image](https://hackmd.io/_uploads/BJdH21ZyGl.png)
![image](https://hackmd.io/_uploads/r1kun1bJGx.png)

> AssocieZ une ip flottante à l'instance
![image](https://hackmd.io/_uploads/rko52JZyMg.png)
![image](https://hackmd.io/_uploads/rJqsnk-Jfe.png)
![image](https://hackmd.io/_uploads/SJthn1-Jzx.png)
![image](https://hackmd.io/_uploads/BJ_ahybJMe.png)

### Erreurs rencontrées et corrections

| Erreur | Cause | Solution |
|--------|-------|----------|
| `403 flavor-manage` | Infomaniak n'autorise pas les flavors custom | Utiliser un flavor existant via `flavor_id` |
| `Volume type HDD not found` | Type inexistant chez Infomaniak | Remplacer par `CEPH_1_perf1` |
| `SecurityGroupRuleExists` | Règle egress créée par défaut | Supprimer la ressource egress du main.tf |
| `availability zone not available` | Zone `dc3-a-02` inexistante | Utiliser `az-1`, `az-2` ou `az-3` |
| `floatingip_associate deprecated` | Ressource dépréciée | Utiliser `openstack_networking_floatingip_associate_v2` |
| `HashiCorp repo 404` | Ubuntu 25.04 non supporté par le repo APT | Installer Terraform via binaire direct |

---

## Accès à PNETLab

```bash
# Interface web
http://83.228.248.244
# Login : admin
# Password : défini dans pnetlab_admin_password
```
![image](https://hackmd.io/_uploads/Hk5yTJW1Gl.png)
![image](https://hackmd.io/_uploads/SkmxpkZkfl.png)
![image](https://hackmd.io/_uploads/SyRZakWJMg.png)
![image](https://hackmd.io/_uploads/B1AzTk-yMe.png)

> pensez à vous déconnecter et vous reconnecter pour vérifier si votre mot de passe à bien été mis à jour

![image](https://hackmd.io/_uploads/Bk7rTyZyfe.png)

```bash
# SSH
ssh -i ~/.ssh/id_rsa_pnetlab root@83.228.248.244
# Mot de passe root par défaut : pnet
```

![image](https://hackmd.io/_uploads/rk7L6JZkGe.png)

---

## Configuration initiale (wizard SSH)

Au premier login SSH, PNETLab lance un assistant de configuration :

| Étape | Valeur recommandée |
|-------|-------------------|
| Root Password | Choisir un mot de passe fort |
| DNS domain name | exemple: `lab.local` |
| DHCP/Static | `dhcp` |
| NTP server | Laisser vide ou `pool.ntp.org` |
| Proxy | `direct connection` |

![image](https://hackmd.io/_uploads/HkItpkbkfe.png)
![image](https://hackmd.io/_uploads/Bykcp1WJMg.png)
![image](https://hackmd.io/_uploads/BkOhT1Wyzx.png)
![image](https://hackmd.io/_uploads/SyJ6pkWkGg.png)
![image](https://hackmd.io/_uploads/HJU6a1byMx.png)
![image](https://hackmd.io/_uploads/Bk0ppJWJzx.png)
![image](https://hackmd.io/_uploads/B15RakbkGe.png)
![image](https://hackmd.io/_uploads/r1G1RJWkzl.png)
![image](https://hackmd.io/_uploads/rkNg01-JMx.png)
![image](https://hackmd.io/_uploads/Bk0eAyWkGg.png)
![image](https://hackmd.io/_uploads/HJ9bRkWkMe.png)

---

## Ajout d'images réseau (ishare2)

### Installation d'ishare2

```bash
# Sur la VM PNETLab
wget -O /usr/sbin/ishare2 \
  https://raw.githubusercontent.com/ishare2-org/ishare2-cli/main/ishare2
chmod +x /usr/sbin/ishare2

# Corriger le fichier sources.list corrompu (repo PNETLab obsolète)
echo "" > /opt/ishare2/cli/sources.list

# Configuration
ishare2 config
# Branch : 2 (main)
# Mirror : 1 (rotation automatique)
# aria2c  : N (désactiver pour éviter les conflits)

# Tester la connectivité
ishare2 test
# Tous les services doivent afficher [+] reachable
```

![image](https://hackmd.io/_uploads/B1zXRyWJfx.png)
![image](https://hackmd.io/_uploads/SkyNCk-Jfe.png)
![image](https://hackmd.io/_uploads/Hk3P01ZyGg.png)
![image](https://hackmd.io/_uploads/HyMtAyZJGe.png)
![image](https://hackmd.io/_uploads/ry6FRJZ1fl.png)
![image](https://hackmd.io/_uploads/B1enCk-yMl.png)
![image](https://hackmd.io/_uploads/BJ-TCkZ1zx.png)
![image](https://hackmd.io/_uploads/HJPpAJZJGx.png)
![image](https://hackmd.io/_uploads/r1UA0yZyfl.png)
![image](https://hackmd.io/_uploads/Hy8z1x-yMg.png)

![image](https://hackmd.io/_uploads/BJGZ1gbkfx.png)

### Téléchargement des images

> **Limitation importante** : LabHub bloque les téléchargements automatisés depuis les IPs de serveurs cloud (Infomaniak, AWS, OVH). Il faut télécharger manuellement depuis un navigateur puis transférer via SFTP.

```bash
# Chercher une image
ishare2 search palo
ishare2 search forti
ishare2 search vios
ishare2 search iol

# Structure de stockage des images
/opt/unetlab/addons/
├── dynamips/    → images Cisco Dynamips (.image)
├── iol/         → images Cisco IOL (.bin)
└── qemu/        → images QEMU
    └── paloalto-11.2.5/
        └── hda.qcow2

# Après chaque ajout d'image
/opt/unetlab/wrappers/unl_wrapper -a fixpermissions
```

### Transfert manuel via MobaXterm SFTP

1. Télécharger l'image depuis [https://labhub.eu.org/0:/addons/qemu/](https://labhub.eu.org/0:/addons/qemu/)
![image](https://hackmd.io/_uploads/r1OqNlbkMg.png)
![image](https://hackmd.io/_uploads/rkBRNgZyMg.png)

3. Ouvrir **MobaXterm** → Session **SFTP** → `83.228.248.244` / `root` / port `22`
![image](https://hackmd.io/_uploads/Skvkl0gJMl.png)

4. Naviguer vers `/opt/unetlab/addons/qemu/`
5. Glisser-déposer le fichier `.tgz`
![image](https://hackmd.io/_uploads/rkSWlAxJMg.png)
![image](https://hackmd.io/_uploads/SJ1xHg-yzg.png)

6. Sur la VM, extraire :

```bash
tar -xzf /opt/unetlab/addons/qemu/paloalto-11.2.5.tgz
/opt/unetlab/wrappers/unl_wrapper -a fixpermissions
rm /opt/unetlab/addons/qemu/paloalto-11.2.5.tgz
```
![image](https://hackmd.io/_uploads/Bkv-Be-Jfx.png)
![image](https://hackmd.io/_uploads/Syiwrg-Jfl.png)

---

## Problème connu : Nested KVM

```bash
# Vérification sur la VM
ls /dev/kvm
# ls: cannot access '/dev/kvm': No such file or directory

cat /proc/cpuinfo | grep vmx
# (aucun résultat)
```
![image](https://hackmd.io/_uploads/SJptlAekGx.png)

**Statut** : En attente d'activation par le support Infomaniak.

**Impact** : Les nœuds QEMU lourds (Palo Alto, Cisco CSR, FortiGate) démarrent puis s'éteignent immédiatement sans KVM.

**Contournement** : Utiliser les nœuds IOL et Docker qui fonctionnent sans KVM.

```bash
ishare2 search iol     # Cisco IOL — fonctionne sans KVM
ishare2 search docker  # Conteneurs Docker — fonctionne sans KVM
```

---

## Capacités de la VM en termes de nœuds PNETLab

| Type de nœud | Nombre estimé | Nécessite KVM |
|--------------|---------------|:-------------:|
| IOL (Cisco IOS on Linux) | ~80–100 nœuds | Non |
| Docker | Illimité (RAM) | Non |
| Dynamips | ~30–40 nœuds | Non |
| vIOS / vIOS-L2 | ~20–30 nœuds | Oui |
| CSRv1000 / XRv | ~6–8 nœuds | Oui |
| FortiGate / PAN-OS | ~4–6 nœuds | Oui |
| SD-WAN (vEdge + controllers) | ~8–10 nœuds | Oui |

---

## Destruction de l'infrastructure

```bash
# Supprimer TOUT (instance + réseau + volume + image)
terraform destroy

# Garder le volume de données (labs)
terraform destroy \
  -target=openstack_compute_instance_v2.pnetlab \
  -target=openstack_networking_floatingip_v2.pnetlab_fip
```

---

## Conclusion

Ce projet m'a permis de déployer avec succès une instance PNETLab entièrement fonctionnelle sur le cloud public Infomaniak en utilisant Terraform comme outil d'IaC. L'ensemble de l'infrastructure (réseau, sécurité, stockage, VM, IP publique) est provisionné de manière automatisée et reproductible en une seule commande `terraform apply`.

Plusieurs obstacles techniques ont été rencontrés et résolus en cours de projet :
- Incompatibilité du repo HashiCorp APT avec Ubuntu 25.04 → résolu par installation via binaire
- Restrictions des permissions OpenStack chez Infomaniak (flavors custom, types de volumes) → adaptées aux ressources disponibles
- Blocage des téléchargements LabHub depuis les IPs cloud → contourné par transfert SFTP manuel
- Absence de Nested KVM → signalée au support Infomaniak, contournée par l'utilisation de nœuds IOL et Docker

Le principal point d'amélioration restant est l'activation du **Nested KVM** par le support Infomaniak, qui permettra d'utiliser l'ensemble des équipements réseau QEMU disponibles sur PNETLab (Palo Alto, FortiGate, Cisco CSR, etc.) et d'exploiter pleinement la capacité de la VM.

---

*Documentation réalisée le 12.05.2026 — Alexandra ASSAGA*
