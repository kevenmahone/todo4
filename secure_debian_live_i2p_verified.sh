#!/bin/bash

# ============================================================
# Secure Debian Live + Java I2P + I2PSnark
# Debian 13 (Trixie)
#
# UFW REMOVED
#
# Includes:
# - System detection
# - Logging
# - Package installation
# - Official I2P repository
# - Java installation
# - I2P installation and verification
# - I2P configuration
# - I2PSnark information
# - AppArmor
# - Kernel hardening
# - Firefox I2P profile
# - Firejail
# - Lynis audit
#
# ============================================================


# ------------------------------------------------------------
# COLORS
# ------------------------------------------------------------

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
NC="\033[0m"


# ------------------------------------------------------------
# LOGGING
# ------------------------------------------------------------

LOGFILE="/tmp/debian-live-i2p-setup.log"

exec > >(tee -a "$LOGFILE") 2>&1

echo "============================================"
echo " Debian Live I2P Setup Log"
echo " $(date)"
echo "============================================"


# ------------------------------------------------------------
# ROOT CHECK
# ------------------------------------------------------------

if [ "$EUID" -ne 0 ]
then
    echo -e "${RED}[ERROR] Run this script as root${NC}"
    echo "Use:"
    echo "sudo bash secure_debian_live_i2p_verified.sh"
    exit 1
else
    echo -e "${GREEN}[OK] Running as root${NC}"
fi


# ------------------------------------------------------------
# CHECK DEBIAN
# ------------------------------------------------------------

if [ -f /etc/debian_version ]
then
    echo -e "${GREEN}[OK] Debian detected${NC}"

    echo "Debian version:"
    cat /etc/debian_version
else
    echo -e "${RED}[ERROR] Not a Debian system${NC}"
    exit 1
fi


# ------------------------------------------------------------
# CHECK DEBIAN VERSION
# ------------------------------------------------------------

if [ -f /etc/os-release ]
then
    . /etc/os-release

    echo "Operating system:"
    echo "$PRETTY_NAME"

    echo "Codename:"
    echo "${VERSION_CODENAME:-unknown}"
else
    echo -e "${RED}[ERROR] /etc/os-release not found${NC}"
    exit 1
fi


if [ "${VERSION_CODENAME:-}" != "trixie" ]
then
    echo -e "${RED}[ERROR] This script is intended for Debian 13 Trixie${NC}"
    echo "Detected codename: ${VERSION_CODENAME:-unknown}"
    exit 1
fi

echo -e "${GREEN}[OK] Debian 13 Trixie detected${NC}"


# ------------------------------------------------------------
# INTERNET CHECK
# ------------------------------------------------------------

echo "[+] Checking internet connection"

if ping -c 1 deb.debian.org >/dev/null 2>&1
then
    echo -e "${GREEN}[OK] Internet available${NC}"
else
    echo -e "${YELLOW}[WARNING] Ping check failed${NC}"
    echo "APT may still work if ICMP is blocked."
fi


# ------------------------------------------------------------
# UPDATE PACKAGE DATABASE
# ------------------------------------------------------------

echo "============================================"
echo " Updating Debian package database"
echo "============================================"

apt update

if [ $? -ne 0 ]
then
    echo -e "${RED}[ERROR] apt update failed${NC}"
    exit 1
fi

echo -e "${GREEN}[OK] Debian repositories updated${NC}"


# ============================================================
# INSTALL DEPENDENCIES
# ============================================================

echo "============================================"
echo " Installing dependencies"
echo "============================================"

apt install -y \
curl \
wget \
gnupg \
ca-certificates \
apt-transport-https \
apparmor \
apparmor-utils \
firejail \
lynis

if [ $? -ne 0 ]
then
    echo -e "${RED}[ERROR] Dependency installation failed${NC}"
    exit 1
fi

echo -e "${GREEN}[OK] Dependencies installed${NC}"


# ============================================================
# JAVA
# ============================================================

echo "============================================"
echo " Installing Java"
echo "============================================"

if command -v java >/dev/null 2>&1
then
    echo -e "${GREEN}[OK] Java already installed${NC}"
else

    apt install -y default-jre

    if command -v java >/dev/null 2>&1
    then
        echo -e "${GREEN}[OK] Java installed${NC}"
    else
        echo -e "${RED}[ERROR] Java installation failed${NC}"
        exit 1
    fi

fi


echo ""
echo "Java version:"
java -version


# ============================================================
# I2P OFFICIAL REPOSITORY
# Debian 13 Trixie
# ============================================================

echo "============================================"
echo " Configuring official I2P repository"
echo "============================================"


I2P_KEYRING="/usr/share/keyrings/i2p-archive-keyring.gpg"
I2P_SOURCE="/etc/apt/sources.list.d/i2p.list"


# Remove old repository configuration

echo "[+] Removing old I2P repository configuration"

rm -f "$I2P_SOURCE"
rm -f "$I2P_KEYRING"


# Download official I2P repository key

echo "[+] Downloading official I2P repository key"

if curl -fsSL \
    https://i2p.net/i2p-archive-keyring.gpg \
    -o "$I2P_KEYRING"
then
    echo -e "${GREEN}[OK] I2P repository key downloaded${NC}"
else
    echo -e "${RED}[ERROR] Could not download I2P repository key${NC}"
    exit 1
fi


# Verify key exists

if [ ! -s "$I2P_KEYRING" ]
then
    echo -e "${RED}[ERROR] I2P keyring is empty or missing${NC}"
    exit 1
fi


chmod 0644 "$I2P_KEYRING"


# Add official I2P repository

echo "[+] Adding I2P Trixie repository"

cat > "$I2P_SOURCE" /dev/null 2>&1
then

    echo -e "${GREEN}[OK] i2prouter found${NC}"

    echo ""
    echo "I2P version:"
    i2prouter version || true

else

    echo -e "${RED}[ERROR] i2prouter missing after I2P installation${NC}"

    echo ""
    echo "Installed I2P packages:"
    dpkg -l | grep -i i2p || true

    echo ""
    echo "I2P files:"
    dpkg -L i2p 2>/dev/null | grep -E 'i2prouter|router' || true

    exit 1
fi


# ============================================================
# VERIFY COMMANDS
# ============================================================

echo "============================================"
echo " Command verification"
echo "============================================"


check_command()
{
    CMD="$1"

    if command -v "$CMD" >/dev/null 2>&1
    then
        echo -e "${GREEN}[OK] $CMD available${NC}"
    else
        echo -e "${RED}[ERROR] $CMD missing${NC}"
    fi
}


check_command java
check_command i2prouter
check_command firejail
check_command lynis


# ============================================================
# FIND REAL USER
# ============================================================

echo "============================================"
echo " Detecting user"
echo "============================================"


if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]
then
    REAL_USER="$SUDO_USER"
else
    REAL_USER=$(who | awk 'NR==1 {print $1}')
fi


if [ -z "$REAL_USER" ] || [ "$REAL_USER" = "root" ]
then
    REAL_USER="root"
    USER_HOME="/root"
else
    USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

    if [ -z "$USER_HOME" ]
    then
        USER_HOME="/home/$REAL_USER"
    fi
fi


echo "User: $REAL_USER"
echo "Home: $USER_HOME"


# ============================================================
# I2P DOWNLOAD DIRECTORY
# ============================================================

echo "============================================"
echo " Creating I2P download directory"
echo "============================================"


DOWNLOAD_DIR="$USER_HOME/I2P-Downloads"

mkdir -p "$DOWNLOAD_DIR"


if [ -d "$DOWNLOAD_DIR" ]
then
    echo -e "${GREEN}[OK] Download folder exists${NC}"
else
    echo -e "${RED}[ERROR] Download folder creation failed${NC}"
fi


if [ "$REAL_USER" != "root" ]
then
    chown -R "$REAL_USER:$REAL_USER" "$DOWNLOAD_DIR"
fi


# ============================================================
# I2P CONFIGURATION
# ============================================================

echo "============================================"
echo " Configuring I2P"
echo "============================================"


I2P_DIR="$USER_HOME/.i2p"

mkdir -p "$I2P_DIR"


if [ -f "$I2P_DIR/router.config" ]
then

    cp "$I2P_DIR/router.config" \
       "$I2P_DIR/router.config.backup"

    echo -e "${GREEN}[OK] I2P config backup created${NC}"

fi


cat > "$I2P_DIR/router.config" /dev/null
then
    echo -e "${GREEN}[OK] I2P process running${NC}"
else
    echo -e "${YELLOW}[WARNING] I2P process not detected${NC}"
fi


# ============================================================
# APPARMOR
# ============================================================

echo "============================================"
echo " Checking AppArmor"
echo "============================================"


systemctl start apparmor 2>/dev/null || true


if aa-status >/dev/null 2>&1
then
    echo -e "${GREEN}[OK] AppArmor active${NC}"
else
    echo -e "${YELLOW}[WARNING] AppArmor status unknown${NC}"
fi


# ============================================================
# KERNEL HARDENING
# ============================================================

echo "============================================"
echo " Applying Kernel Security"
echo "============================================"


cat >> /etc/sysctl.conf  "$FIREFOX_DIR/user.js"  Network Settings"
echo " -> Manual proxy configuration"
echo ""
echo "HTTP Proxy:"
echo "127.0.0.1"
echo ""
echo "Port:"
echo "4444"
echo ""
echo "Use this proxy for HTTPS: YES"
echo ""


# ============================================================
# TEST I2P SERVICES
# ============================================================

echo "============================================"
echo " Testing I2P Services"
echo "============================================"


if curl -s --max-time 10 http://127.0.0.1:7657 >/dev/null
then
    echo -e "${GREEN}[OK] I2P console reachable${NC}"
else
    echo -e "${YELLOW}[WARNING] I2P console not reachable${NC}"
fi


if curl -s --max-time 10 \
    http://127.0.0.1:7657/i2psnark/ >/dev/null
then
    echo -e "${GREEN}[OK] I2PSnark available${NC}"
else
    echo -e "${YELLOW}[WARNING] I2PSnark not detected${NC}"
fi


# ============================================================
# FIREJAIL
# ============================================================

echo "============================================"
echo " Firejail Verification"
echo "============================================"


if command -v firejail >/dev/null 2>&1
then
    echo -e "${GREEN}[OK] Firejail installed${NC}"
else
    echo -e "${RED}[ERROR] Firejail missing${NC}"
fi


# ============================================================
# LYNIS
# ============================================================

echo "============================================"
echo " Security Audit"
echo "============================================"


if command -v lynis >/dev/null 2>&1
then

    echo "[+] Running quick Lynis audit"

    lynis audit system --quick || true

else

    echo -e "${YELLOW}[WARNING] Lynis unavailable${NC}"

fi


# ============================================================
# FINAL REPORT
# ============================================================

echo ""
echo "================================================"
echo " Debian Live Java I2P Security Report"
echo "================================================"

echo ""


# I2P

if command -v i2prouter >/dev/null 2>&1
then
    echo -e "${GREEN}[OK] I2P installed${NC}"
else
    echo -e "${RED}[FAIL] I2P missing${NC}"
fi


# Java

if command -v java >/dev/null 2>&1
then
    echo -e "${GREEN}[OK] Java installed${NC}"
else
    echo -e "${RED}[FAIL] Java missing${NC}"
fi


# Download folder

if [ -d "$DOWNLOAD_DIR" ]
then
    echo -e "${GREEN}[OK] Download folder ready${NC}"
else
    echo -e "${RED}[FAIL] Download folder missing${NC}"
fi


# AppArmor

if aa-status >/dev/null 2>&1
then
    echo -e "${GREEN}[OK] AppArmor available${NC}"
else
    echo -e "${YELLOW}[WARNING] AppArmor unknown${NC}"
fi


echo ""
echo "================================================"
echo " SETUP FINISHED"
echo "================================================"

echo ""

echo "Next steps:"
echo ""
echo "1) Open I2P:"
echo "   http://127.0.0.1:7657"
echo ""
echo "2) Open I2PSnark:"
echo "   http://127.0.0.1:7657/i2psnark/"
echo ""
echo "3) Configure Firefox proxy:"
echo "   127.0.0.1:4444"
echo ""
echo "4) Stop torrents after downloads complete"
echo ""
echo "5) Shutdown Debian Live when finished"
echo ""
echo "Without persistence, changes disappear after reboot."
echo ""

echo "Log saved:"
echo "$LOGFILE"
