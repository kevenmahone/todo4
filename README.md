Voici un script complet pour Debian Live + i2pd + durcissement de base.
Il est conçu pour une session Live sans persistence : 
les changements seront perdus après redémarrage sauf 
si tu crées une image Live personnalisée.

Crée un fichier :
nano secure_debian_live_i2pd.sh


colle ceci



#!/bin/bash

# ============================================================
# Secure Debian Live + i2pd Configuration Script
# Author: ChatGPT
# Purpose:
# Configure a temporary Debian Live session with:
# - i2pd I2P router
# - UFW firewall
# - AppArmor
# - Firejail
# - Kernel security settings
# - Basic system hardening
#
# WARNING:
# Debian Live without persistence loses all changes after reboot.
# Run this script again after every boot.
# ============================================================


# ------------------------------------------------------------
# Check root privileges
# ------------------------------------------------------------

if [ "$EUID" -ne 0 ]; then

    echo "ERROR: Please run this script as root."
    echo "Use: sudo bash secure_debian_live_i2pd.sh"

    exit 1

fi


echo "[+] Starting Debian Live security configuration..."


# ------------------------------------------------------------
# Update package database
# ------------------------------------------------------------

echo "[+] Updating package repositories..."

apt update


# ------------------------------------------------------------
# Install required security packages
# ------------------------------------------------------------

echo "[+] Installing security packages..."

apt install -y \
i2pd \
ufw \
apparmor \
apparmor-utils \
firejail \
lynis \
unattended-upgrades \
apt-listchanges


# ------------------------------------------------------------
# Configure automatic security updates
# ------------------------------------------------------------

echo "[+] Configuring unattended security updates..."

dpkg-reconfigure -f noninteractive unattended-upgrades



# ============================================================
# FIREWALL CONFIGURATION
# ============================================================


echo "[+] Configuring UFW firewall..."


# Block incoming connections by default
ufw default deny incoming


# Block outgoing traffic by default
ufw default deny outgoing


# Allow DNS requests
ufw allow out 53


# Allow HTTPS updates
ufw allow out 443


# Allow HTTP updates
ufw allow out 80


# Allow I2P HTTP proxy
ufw allow out 4444


# Allow I2P router communication
ufw allow out 4447


# Enable firewall
echo "y" | ufw enable



# ============================================================
# KERNEL SECURITY HARDENING
# ============================================================


echo "[+] Applying kernel security settings..."


cat >> /etc/sysctl.conf <<EOF

# Security hardening settings

kernel.kptr_restrict=2

kernel.dmesg_restrict=1

kernel.randomize_va_space=2

kernel.sysrq=0

net.ipv4.conf.all.accept_redirects=0

net.ipv4.conf.default.accept_redirects=0

net.ipv4.conf.all.accept_source_route=0

net.ipv4.icmp_echo_ignore_broadcasts=1

fs.suid_dumpable=0

EOF


# Apply kernel settings
sysctl -p



# ============================================================
# APPARMOR
# ============================================================


echo "[+] Starting AppArmor..."

systemctl start apparmor || true


aa-status || true



# ============================================================
# i2pd CONFIGURATION
# ============================================================


echo "[+] Configuring i2pd..."


I2PD_CONFIG="/etc/i2pd/i2pd.conf"


# Backup original configuration

if [ -f "$I2PD_CONFIG" ]; then

cp "$I2PD_CONFIG" "$I2PD_CONFIG.backup"

fi



cat > "$I2PD_CONFIG" <<EOF

# Secure i2pd configuration

# Disable IPv6
ipv6=false


# Limit bandwidth usage
bandwidth=B


# Do not participate as transit router
notransit=true


# Disable floodfill mode
floodfill=false


# Enable local HTTP proxy
httpproxy.enabled=true


# Listen only locally
httpproxy.address=127.0.0.1


# HTTP proxy port
httpproxy.port=4444


# Disable SOCKS proxy
socksproxy.enabled=false


EOF



# ============================================================
# START i2pd
# ============================================================


echo "[+] Starting i2pd service..."


systemctl restart i2pd || true


systemctl status i2pd --no-pager || true



# ============================================================
# FIREJAIL CONFIGURATION
# ============================================================


echo "[+] Installing Firejail profiles..."


firecfg || true



# ============================================================
# BASIC SECURITY CHECK
# ============================================================


echo "[+] Running security audit..."

lynis audit system --quick || true



# ============================================================
# FINAL INFORMATION
# ============================================================


echo ""
echo "=============================================="
echo " Debian Live i2pd security setup completed"
echo "=============================================="
echo ""
echo "I2P HTTP proxy:"
echo "127.0.0.1:4444"
echo ""
echo "Remember:"
echo "- Changes disappear after reboot without persistence"
echo "- Use a separate browser profile for I2P"
echo "- Avoid personal accounts"
echo "- Do not open unknown files"
echo ""
echo "=============================================="











Pour l'exécuter :
chmod +x secure_debian_live_i2pd.sh



Puis :
sudo ./secure_debian_live_i2pd.sh








Configurer le proxy I2P
Dans Firefox :
Menu ☰
→ Settings (Paramètres)
→ Network Settings (Paramètres réseau)
→ Settings...
Choisis :
Manual proxy configuration
Mets :
HTTP Proxy:
127.0.0.1

Port:
4444
Coche :
[x] Also use this proxy for HTTPS

Laisse vide :
SOCKS Host
Puis valide.




Tester que i2pd fonctionne
Dans Firefox ouvre :
http://127.0.0.1:7070
Tu devrais voir la console web i2pd.
Elle montre :
état du routeur I2P ;
tunnels actifs ;
connexions ;
bande passante.






