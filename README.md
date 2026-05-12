# PNETLab sur Infomaniak Public Cloud — Déploiement Terraform
## Par : Alexandra ASSAGA
## Date: 12.05.2026
## Architecture déployée

```
Internet
   │
   │ IP flottante publique (83.228.248.244)
   ▼
[routeur OpenStack]
   │
   │ 192.168.100.0/24
   ▼
[VM PNETLab] ── sg-pnetlab (SSH/HTTP/HTTPS/Telnet/VNC)
  8 vCPU | 32 Go RAM | 50 Go + volume 200 Go
  Nested KVM en attente d'activation (support Infomaniak)
```

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
# Terraform >= 1.9 (installation via binaire sur Ubuntu 25.04)
wget https://releases.hashicorp.com/terraform/1.9.8/terraform_1.9.8_linux_amd64.zip
unzip terraform_1.9.8_linux_amd64.zip
sudo mv terraform /usr/local/bin/
terraform version

# OpenStack CLI
sudo apt install python3-openstackclient -y

# QEMU tools (pour convertir l'image)
sudo apt install qemu-system -y
qemu-img --version
```

> **Note Ubuntu 25.04 (Resolute)** : Le repo HashiCorp APT ne supporte pas encore cette version. Utiliser le binaire direct comme indiqué ci-dessus.

### 2. Préparer l'image PNETLab

Télécharger l'OVA depuis https://pnetlab.com/pages/download (version 4.2.10)

```bash
# Se placer dans le dossier Downloads
cd /mnt/c/Users/<user>/Downloads

# Extraire le VMDK depuis l'OVA
tar -xvf PNET_4.2.10.ova
# Produit : PNET_4.2.10.ovf, PNET_4.2.10.mf, PNET_4.2.10-disk1.vmdk

# Convertir en QCOW2 (format OpenStack)
qemu-img convert -f vmdk -O qcow2 PNET_4.2.10-disk1.vmdk pnetlab.qcow2

# Vérifier (doit afficher virtual size: 100 GiB, disk size: ~5.56 GiB)
qemu-img info pnetlab.qcow2
```

### 3. Récupérer les credentials OpenStack

Depuis Horizon → **Accès API** → **Télécharger le fichier RC OpenStack v3**

```bash
# Créer le fichier de variables d'environnement
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

### 4. Vérifier les ressources disponibles

```bash
# Réseau externe
openstack network list --external
# ext-floating1 : 34a684b8-2889-4950-b08e-c33b3954a307

# Zones de disponibilité
openstack availability zone list
# az-1, az-2, az-3 (utiliser az-1)

# Flavors disponibles
openstack flavor list
# Flavor choisi : a8-ram32-disk50-perf1
# ID : 3a4c0e4f-b272-4aa0-959a-eb4088c87b6d

# Types de volumes
openstack volume type list
# CEPH_1_perf1 (seul type disponible)
```

### 5. Générer une clé SSH dédiée

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa_pnetlab -C "pnetlab-infomaniak"
```

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

### Résultat obtenu
```
Outputs:
pnetlab_floating_ip  = "83.228.248.244"
pnetlab_web_url      = "http://83.228.248.244"
pnetlab_ssh_command  = "ssh -i ~/.ssh/id_rsa_pnetlab root@83.228.248.244"
pnetlab_private_ip   = "192.168.100.203"
image_id             = "c1ec55d2-6136-4a27-ba1e-c728fa11e34b"
```

### Erreurs rencontrées et corrections

| Erreur | Cause | Solution |
|--------|-------|----------|
| `403 flavor-manage` | Infomaniak n'autorise pas la création de flavors custom | Utiliser un flavor existant via `flavor_id` |
| `Volume type HDD not found` | Type inexistant chez Infomaniak | Remplacer par `CEPH_1_perf1` |
| `SecurityGroupRuleExists` | Règle egress déjà créée par défaut | Supprimer la ressource egress du main.tf |
| `availability zone not available` | Zone `dc3-a-02` inexistante | Utiliser `az-1`, `az-2` ou `az-3` |
| `floatingip_associate deprecated` | Ressource dépréciée | Utiliser `openstack_networking_floatingip_associate_v2` |

---

## Accès à PNETLab

```bash
# Interface web
http://83.228.248.244
# Login : admin / Password : défini dans pnetlab_admin_password

# SSH
ssh -i ~/.ssh/id_rsa_pnetlab root@83.228.248.244
# Mot de passe root PNETLab par défaut : pnet
# Un wizard de configuration s'ouvre au premier login SSH
```

---

## Configuration initiale (wizard SSH)

Au premier login SSH, PNETLab lance un assistant de configuration :

| Étape | Valeur recommandée |
|-------|-------------------|
| Root Password | Choisir un mot de passe fort |
| DNS domain name | `lab.local` |
| DHCP/Static | `dhcp` |
| NTP server | Laisser vide ou `pool.ntp.org` |
| Proxy | `direct connection` |

---

## Ajout d'images réseau (ishare2)

### Installation d'ishare2
```bash
# Sur la VM PNETLab
wget -O /usr/sbin/ishare2 https://raw.githubusercontent.com/ishare2-org/ishare2-cli/main/ishare2
chmod +x /usr/sbin/ishare2

# Corriger le fichier sources.list corrompu
echo "" > /opt/ishare2/cli/sources.list

# Lancer la configuration
ishare2 config
# Branch : 2 (main)
# Mirror : 1 (rotation automatique)

# Tester la connectivité
ishare2 test
```

### Téléchargement des images

> **Important** : LabHub bloque les téléchargements depuis les IPs de serveurs cloud (Infomaniak, AWS, OVH). Il faut télécharger manuellement depuis un navigateur puis transférer via SFTP (ex: MobaXterm).

```bash
# Chercher une image
ishare2 search forti
ishare2 search vios
ishare2 search palo

# Structure des images
/opt/unetlab/addons/
├── dynamips/     → images Cisco Dynamips
├── iol/          → images Cisco IOL
└── qemu/         → images QEMU (Palo Alto, FortiGate, Juniper...)
    └── paloalto-11.2.5/
        └── hda.qcow2

# Après chaque ajout d'image
/opt/unetlab/wrappers/unl_wrapper -a fixpermissions
```

### Transfert manuel via MobaXterm SFTP
1. Télécharger l'image depuis `https://legacy.labhub.eu.org/0:/addons/qemu/`
2. Ouvrir MobaXterm → Session SFTP → `83.228.248.244` / `root` / port `22`
3. Déposer le fichier dans `/opt/unetlab/addons/qemu/`
4. Sur la VM, extraire et fixer les permissions

---

## Problème connu : Nested KVM

```bash
# Vérification
ls /dev/kvm
# ls: cannot access '/dev/kvm': No such file or directory
```

**Statut** : En attente d'activation par le support Infomaniak.

**Impact** : Les nœuds QEMU lourds (Palo Alto, Cisco CSR, FortiGate) ne démarrent pas sans KVM.

**Contournement** : Utiliser les nœuds IOL et Docker qui fonctionnent sans KVM.

```bash
ishare2 search iol     # Cisco IOL (fonctionne sans KVM)
ishare2 search docker  # Conteneurs Docker (fonctionne sans KVM)
```

---

## Capacités de la VM en termes de nœuds PNETLab

| Type de nœud | Nombre estimé | Nécessite KVM |
|--------------|---------------|---------------|
| IOL (Cisco IOS on Linux) | ~80–100 nœuds | Non |
| Docker | illimité (RAM) | Non |
| vIOS / vIOS-L2 | ~20–30 nœuds | Oui |
| Dynamips | ~30–40 nœuds | Non |
| CSRv1000 / XRv | ~6–8 nœuds | Oui |
| FortiGate / PAN-OS | ~4–6 nœuds | Oui |
| SD-WAN (vEdge + controllers) | ~8–10 nœuds | Oui |

---

## Destruction de l'infrastructure

```bash
terraform destroy
# Supprime TOUT, y compris le volume de données PNETLab
```

Pour garder les données, retirer uniquement l'instance :
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
├── userdata.sh               # Script post-boot
├── terraform.tfvars.example  # Exemple de configuration
├── .gitignore                # Exclut terraform.tfvars et .terraform/
└── README.md                 # Ce fichier
```

---

## Notes importantes

- **Nested KVM** : À activer via le support Infomaniak pour les nœuds QEMU.
- **Sécurité** : `admin_cidr = "0.0.0.0/0"` pour un lab. Restreindre en production.
- **Stockage** : Volume type `CEPH_1_perf1` — seul type disponible chez Infomaniak.
- **Ubuntu 25.04** : Le repo HashiCorp APT ne supporte pas encore Resolute, installer Terraform via binaire.
- **LabHub** : Téléchargements manuels nécessaires depuis les serveurs cloud (IP bloquées).
