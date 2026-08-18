#!/bin/bash

# ============================================================
# Secure Debian Live + Java I2P + I2PSnark Setup
#
# Purpose:
# - Prepare a temporary Debian Live session
# - Install Java I2P router
# - Install I2PSnark support
# - Apply basic security hardening
#
# Design:
# - No persistence required
# - Works from RAM-based Debian Live
# - Intended to be re-run after every reboot
#
# WARNING:
# A script cannot guarantee compatibility forever.
# Debian, Java and I2P configurations can change.
# This script checks availability before applying changes.
# ============================================================


# ------------------------------------------------------------
# Require root privileges
# ------------------------------------------------------------

if [ "$EUID" -ne 0 ]; then

    echo "ERROR: Run this script as root"
    echo "Example:"
    echo "sudo bash secure_debian_live_i2p.sh"

    exit 1

fi


echo "[+] Starting Debian Live I2P security setup"


# ------------------------------------------------------------
# Detect Debian system
# ------------------------------------------------------------

if [ -f /etc/debian_version ]; then

    echo "[+] Debian system detected"

else

    echo "ERROR: This script requires Debian"
    exit 1

fi



# ------------------------------------------------------------
# Update package database
# ------------------------------------------------------------

echo "[+] Updating repositories"

apt update



# ------------------------------------------------------------
# Install required packages
#
# i2p:
# Java I2P router + I2PSnark
#
# openjdk:
# Java runtime required by I2P
#
# security tools:
# firewall, sandbox, auditing
# ------------------------------------------------------------


echo "[+] Installing packages"


PACKAGES="
i2p
openjdk-17-jre
ufw
apparmor
apparmor-utils
firejail
lynis
curl
wget
ca-certificates
"


for PACKAGE in $PACKAGES
do

    if apt-cache show "$PACKAGE" >/dev/null 2>&1
    then

        apt install -y "$PACKAGE"

    else

        echo "[!] Package not available: $PACKAGE"

    fi

done



# ------------------------------------------------------------
# Create I2P download directory
# ------------------------------------------------------------

echo "[+] Creating download directory"


REAL_USER=$(logname 2>/dev/null || echo root)


if [ "$REAL_USER" != "root" ]; then

    mkdir -p /home/$REAL_USER/I2P-Downloads

    chown $REAL_USER:$REAL_USER /home/$REAL_USER/I2P-Downloads

else

    mkdir -p /root/I2P-Downloads

fi



# ============================================================
# FIREWALL CONFIGURATION
# ============================================================


echo "[+] Configuring firewall"


# Default deny incoming traffic

ufw default deny incoming


# Default deny outgoing traffic

ufw default deny outgoing



# Allow DNS

ufw allow out 53


# Allow HTTPS package updates

ufw allow out 443


# Allow HTTP package updates

ufw allow out 80



# I2P local proxy

ufw allow out 4444



# I2P router communication

ufw allow out 7654


# Enable firewall

echo "y" | ufw enable



# ============================================================
# KERNEL HARDENING
# ============================================================


echo "[+] Applying kernel security settings"


SYSCTL_FILE="/etc/sysctl.conf"


cat >> "$SYSCTL_FILE" <<EOF


# Debian Live security settings

kernel.kptr_restrict=2

kernel.dmesg_restrict=1

kernel.randomize_va_space=2

kernel.sysrq=0

fs.suid_dumpable=0

net.ipv4.conf.all.accept_redirects=0

net.ipv4.conf.default.accept_redirects=0

net.ipv4.conf.all.accept_source_route=0

EOF



sysctl -p



# ============================================================
# APPARMOR
# ============================================================


echo "[+] Starting AppArmor"


systemctl start apparmor 2>/dev/null || true


aa-status 2>/dev/null || true



# ============================================================
# FIREJAIL
# ============================================================


echo "[+] Preparing Firejail"


firecfg 2>/dev/null || true



echo ""
echo "=============================================="
echo " PART 1 COMPLETE"
echo " Next:"
echo " - Configure Java I2P"
echo " - Configure I2PSnark"
echo " - Configure Firefox I2P profile"
echo "=============================================="
