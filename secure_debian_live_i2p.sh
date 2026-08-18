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





# ============================================================
# JAVA I2P CONFIGURATION
# ============================================================

echo "[+] Configuring Java I2P"


# Check if I2P exists

if command -v i2prouter >/dev/null 2>&1
then

    echo "[+] I2P installation detected"

else

    echo "[!] I2P router command not found"
    echo "[!] Check Debian repository availability"

fi



# ------------------------------------------------------------
# Create I2P user configuration directory
# ------------------------------------------------------------


REAL_USER=$(logname 2>/dev/null || echo root)


if [ "$REAL_USER" != "root" ]; then

    I2P_DIR="/home/$REAL_USER/.i2p"

else

    I2P_DIR="/root/.i2p"

fi


mkdir -p "$I2P_DIR"



# ------------------------------------------------------------
# Backup existing configuration
# ------------------------------------------------------------


if [ -f "$I2P_DIR/i2ptunnel.config" ]
then

    cp "$I2P_DIR/i2ptunnel.config" \
    "$I2P_DIR/i2ptunnel.config.backup"

fi



# ============================================================
# I2P ROUTER HARDENING
# ============================================================


echo "[+] Applying I2P privacy settings"


# Disable automatic router updates
# (manual updates are preferred on Live systems)

cat > "$I2P_DIR/router.config" <<EOF

# Secure Debian Live I2P configuration


# Disable IPv6

i2np.enableIPv6=false


# Disable UPnP

i2np.upnp.enable=false


# Reduce bandwidth usage

i2np.bandwidthLimiter=true


# Disable floodfill participation

router.floodfillParticipant=false


# Do not automatically open ports

i2np.ntcp.autoPortForward=false


i2np.udp.autoPortForward=false


EOF



# ============================================================
# START I2P
# ============================================================


echo "[+] Starting I2P router"


if command -v i2prouter >/dev/null 2>&1
then

    i2prouter start || true

else

    echo "[!] Cannot start I2P automatically"

fi



# ============================================================
# I2PSNARK DOWNLOAD SETTINGS
# ============================================================


echo "[+] Preparing I2PSnark"


echo ""
echo "I2PSnark configuration:"
echo ""
echo "Open:"
echo "http://127.0.0.1:7657/i2psnark/"
echo ""
echo "Recommended settings:"
echo ""
echo "- Disable automatic torrent start"
echo "- Stop torrents after completion"
echo "- Use manual start"
echo "- Set upload limit as low as possible"
echo "- Save files to:"
echo "$HOME/I2P-Downloads"
echo ""



# ============================================================
# FIREFOX I2P PROFILE
# ============================================================


echo "[+] Creating Firefox I2P profile"


FIREFOX_PROFILE="$HOME/.mozilla/firefox/i2p-profile"


mkdir -p "$FIREFOX_PROFILE"



cat > "$FIREFOX_PROFILE/user.js" <<EOF


// =======================================
// Firefox I2P privacy profile
// =======================================


// Disable WebRTC

user_pref("media.peerconnection.enabled", false);


// Disable DNS prefetch

user_pref("network.prefetch-next", false);


// Disable DNS over HTTPS

user_pref("network.trr.mode", 5);


// Disable link prefetch

user_pref("network.http.speculative-parallel-limit", 0);


// Reduce telemetry

user_pref("toolkit.telemetry.enabled", false);


EOF



echo ""
echo "Firefox proxy settings:"
echo ""
echo "Settings → Network Settings → Manual proxy"
echo ""
echo "HTTP Proxy:"
echo "127.0.0.1"
echo ""
echo "Port:"
echo "4444"
echo ""



# ============================================================
# FINAL SECURITY CHECK
# ============================================================


echo "[+] Running Lynis quick audit"


lynis audit system --quick || true



# ============================================================
# FINAL MESSAGE
# ============================================================


echo ""
echo "================================================"
echo " Debian Live Java I2P setup completed"
echo "================================================"
echo ""
echo "I2P Console:"
echo "http://127.0.0.1:7657"
echo ""
echo "I2PSnark:"
echo "http://127.0.0.1:7657/i2psnark/"
echo ""
echo "Firefox proxy:"
echo "127.0.0.1:4444"
echo ""
echo "Downloaded files:"
echo "$HOME/I2P-Downloads"
echo ""
echo "Remember:"
echo "- Debian Live without persistence loses changes"
echo "- Stop torrents manually after downloads"
echo "- Do not use personal accounts"
echo "- Analyze unknown files in a sandbox"
echo ""
echo "================================================"

