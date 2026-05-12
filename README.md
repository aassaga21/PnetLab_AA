# PNETLab sur Infomaniak Public Cloud — Déploiement Terraform

## Architecture déployée

```
Internet
   │
   │ IP flottante publique
   ▼
[routeur OpenStack]
   │
   │ 192.168.100.0/24
   ▼
[VM PNETLab] ── sg-pnetlab (SSH/HTTP/HTTPS/Telnet/VNC)
  8 vCPU | 28 Go RAM | 200 Go HDD
  Nested KVM activé
```

## Ressources créées

| Ressource | Valeur |
|-----------|--------|
| Instance | `vm-pnetlab-01` |
| vCPUs | 8 (sur 20 disponibles) |
| RAM | 28 Go (sur 64 Go disponibles) |
| Disque | 200 Go |
| IP flottante | 1 (sur 10 disponibles) |
| Réseau | `net-pnetlab` — 192.168.100.0/24 |
| Image | PNETLab Custom QCOW2 |

---

## Prérequis

### 1. Outils requis
```bash
# Terraform >= 1.3
brew install terraform        # macOS
sudo apt install terraform    # Ubuntu

# OpenStack CLI (pour vérifier les IDs réseau)
pip install python-openstackclient

# QEMU tools (pour convertir l'image)
sudo apt install qemu-utils   # Ubuntu
brew install qemu             # macOS
```

### 2. Préparer l'image PNETLab

Télécharger l'OVA depuis https://pnetlab.com/pages/download

```bash
# Extraire le VMDK depuis l'OVA
tar -xvf PNETLab_box-5.x.x.ova

# Convertir en QCOW2 (format OpenStack)
qemu-img convert -f vmdk -O qcow2 PNETLab_box-5.x.x-disk001.vmdk pnetlab.qcow2

# Vérifier
qemu-img info pnetlab.qcow2

# Copier dans le répertoire Terraform
cp pnetlab.qcow2 ./pnetlab-infomaniak/
```

### 3. Récupérer les credentials OpenStack

Depuis Horizon → **Accès API** → **Télécharger le fichier RC OpenStack v3**

```bash
source PCP-LPGJL2D-openrc.sh
# Entrer votre mot de passe quand demandé
```

### 4. Vérifier l'ID du réseau externe

```bash
openstack network list --external
# Copier l'ID du réseau "ext-floating1" dans terraform.tfvars
```

---

## Déploiement

```bash
# 1. Cloner / se placer dans le répertoire
cd pnetlab-infomaniak

# 2. Configurer les variables
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars   # remplir vos valeurs

# 3. Initialiser Terraform
terraform init

# 4. Vérifier le plan
terraform plan

# 5. Déployer
terraform apply
# Taper "yes" pour confirmer
# ⏱ L'upload de l'image prend ~5-10 min selon la taille
```

### Résultat attendu
```
Outputs:
pnetlab_floating_ip = "x.x.x.x"
pnetlab_web_url     = "http://x.x.x.x"
pnetlab_ssh_command = "ssh -i ~/.ssh/id_rsa root@x.x.x.x"
```

---

## Accès à PNETLab

```bash
# Interface web (attendre ~3 min après le apply)
open http://<floating_ip>

# Identifiants par défaut PNETLab
Login    : admin
Password : (défini dans pnetlab_admin_password)

# SSH pour diagnostics
ssh -i ~/.ssh/id_rsa root@<floating_ip>
# Mot de passe root par défaut PNETLab : pnet
```

---

## Vérifier que Nested KVM fonctionne

```bash
ssh root@<floating_ip>
cat /sys/module/kvm_intel/parameters/nested
# Doit afficher : 1 ou Y
```

---

## Capacités de la VM en termes de nœuds PNETLab

| Type de nœud | Nombre estimé |
|--------------|---------------|
| IOL (Cisco IOS on Linux) | ~80–100 nœuds |
| vIOS / vIOS-L2 | ~20–30 nœuds |
| Dynamips | ~30–40 nœuds |
| CSRv1000 / XRv | ~6–8 nœuds |
| FortiGate / PAN-OS | ~4–6 nœuds |
| SD-WAN (vEdge + controllers) | ~8–10 nœuds |

---

## Destruction de l'infrastructure

```bash
terraform destroy
# ⚠️ Supprime TOUT, y compris le volume de données PNETLab
```

Pour garder les données, retirer le volume du destroy :
```bash
terraform destroy -target=openstack_compute_instance_v2.pnetlab \
                  -target=openstack_networking_floatingip_v2.pnetlab_fip
```

---

## Fichiers du projet

```
pnetlab-infomaniak/
├── main.tf                   # Ressources principales
├── variables.tf              # Déclaration des variables
├── outputs.tf                # Sorties (IP, URL, etc.)
├── userdata.sh               # Script post-boot (nested KVM, optimisations)
├── terraform.tfvars.example  # Exemple de configuration
└── README.md                 # Ce fichier
```

---

## Notes importantes

- **Nested KVM** : Infomaniak doit avoir activé la virtualisation imbriquée sur l'hyperviseur hôte. Si le flavor `hw:nested_virt=true` n'est pas supporté, contacter le support Infomaniak.
- **Sécurité** : Restreindre `admin_cidr` à votre IP publique, ne jamais laisser `0.0.0.0/0` en production.
- **Stockage** : Le type de volume `HDD` est utilisé par défaut. Remplacer par `SSD` pour de meilleures performances I/O.
