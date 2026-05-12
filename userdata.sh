#!/bin/bash
###############################################################
# userdata.sh - Post-configuration PNETLab au 1er boot
# Exécuté automatiquement par cloud-init
###############################################################

set -euo pipefail
exec > /var/log/pnetlab-init.log 2>&1

echo "=== [PNETLab Init] Démarrage $(date) ==="

# ---------------------------------------------------------------
# 1. Attendre que le réseau soit disponible
# ---------------------------------------------------------------
for i in {1..30}; do
  ping -c1 -W2 8.8.8.8 &>/dev/null && break
  echo "Attente réseau... ($i/30)"
  sleep 5
done

# ---------------------------------------------------------------
# 2. Mise à jour système
# ---------------------------------------------------------------
echo "=== Mise à jour système ==="
apt-get update -qq
apt-get upgrade -y -qq

# ---------------------------------------------------------------
# 3. Activer la virtualisation imbriquée (nested KVM)
#    Indispensable pour que PNETLab puisse lancer ses nœuds QEMU
# ---------------------------------------------------------------
echo "=== Configuration Nested KVM ==="
modprobe kvm_intel nested=1 || modprobe kvm_amd nested=1 || true

# Rendre la config persistante
cat > /etc/modprobe.d/kvm-nested.conf << 'EOF'
options kvm_intel nested=1
options kvm_amd nested=1
EOF

# Vérification
if cat /sys/module/kvm_intel/parameters/nested 2>/dev/null | grep -q "1\|Y"; then
  echo "✓ Nested KVM Intel activé"
elif cat /sys/module/kvm_amd/parameters/nested 2>/dev/null | grep -q "1\|Y"; then
  echo "✓ Nested KVM AMD activé"
else
  echo "⚠ Nested KVM non détecté - vérifier le flavor (hw:nested_virt)"
fi

# ---------------------------------------------------------------
# 4. Optimisations réseau pour PNETLab
# ---------------------------------------------------------------
echo "=== Optimisations réseau ==="
cat >> /etc/sysctl.conf << 'EOF'

# PNETLab optimizations
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
vm.swappiness = 10
EOF
sysctl -p

# ---------------------------------------------------------------
# 5. Hugepages pour améliorer les performances mémoire
# ---------------------------------------------------------------
echo "=== Configuration Hugepages ==="
echo "vm.nr_hugepages = 1024" >> /etc/sysctl.conf
sysctl -w vm.nr_hugepages=1024

# ---------------------------------------------------------------
# 6. Changer le mot de passe admin PNETLab via CLI
#    (PNETLab stocke les configs dans /opt/unetlab)
# ---------------------------------------------------------------
echo "=== Post-config PNETLab ==="
# Attendre que PNETLab soit démarré (service apache2 + mysql)
for i in {1..60}; do
  systemctl is-active apache2 &>/dev/null && \
  systemctl is-active mysql &>/dev/null && break
  echo "Attente services PNETLab... ($i/60)"
  sleep 10
done

# Changer le mot de passe admin dans la base MySQL de PNETLab
if systemctl is-active mysql &>/dev/null; then
  HASHED_PWD=$(echo -n "${admin_password}" | md5sum | cut -d' ' -f1)
  mysql -u root pnetlab -e \
    "UPDATE users SET password='$HASHED_PWD' WHERE username='admin';" 2>/dev/null || true
  echo "✓ Mot de passe admin PNETLab mis à jour"
fi

# ---------------------------------------------------------------
# 7. Fix permissions PNETLab (recommandé après chaque boot)
# ---------------------------------------------------------------
if [ -f /opt/unetlab/html/includes/init.php ]; then
  /opt/unetlab/html/includes/init.php fix 2>/dev/null || true
  echo "✓ Permissions PNETLab corrigées"
fi

# ---------------------------------------------------------------
# 8. Activer le démarrage automatique des services
# ---------------------------------------------------------------
systemctl enable apache2 mysql || true

echo "=== [PNETLab Init] Terminé $(date) ==="
echo "=== Accès web : http://$(curl -s ifconfig.me) ==="
echo "=== Login : admin / ${admin_password} ==="
