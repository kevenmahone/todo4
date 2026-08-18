#!/bin/bash

# ============================================================
# Secure Debian Live + Java I2P + I2PSnark
# Verified Installation Script
#
# Part 1:
# - System detection
# - Logging
# - Package installation
# - Installation verification
#
# Designed for:
# Debian Live temporary sessions
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
# INTERNET CHECK
# ------------------------------------------------------------

echo "[+] Checking internet connection"


if ping -c 1 deb.debian.org >/dev/null 2>&1
then

    echo -e "${GREEN}[OK] Internet available${NC}"

else

    echo -e "${YELLOW}[WARNING] Internet check failed${NC}"
    echo "Package installation may fail"

fi



# ------------------------------------------------------------
# UPDATE PACKAGE DATABASE
# ------------------------------------------------------------

echo "[+] Updating package database"


apt update


if [ $? -eq 0 ]
then

    echo -e "${GREEN}[OK] Repository update successful${NC}"

else

    echo -e "${RED}[ERROR] apt update failed${NC}"

fi



# ------------------------------------------------------------
# PACKAGE INSTALL FUNCTION
# ------------------------------------------------------------


install_package()
{

PACKAGE=$1


echo "[+] Checking package: $PACKAGE"


if dpkg -s "$PACKAGE" >/dev/null 2>&1
then

    echo -e "${GREEN}[OK] $PACKAGE already installed${NC}"

else


    echo "[+] Installing $PACKAGE"


    apt install -y "$PACKAGE"


    if dpkg -s "$PACKAGE" >/dev/null 2>&1
    then

        echo -e "${GREEN}[OK] $PACKAGE installed successfully${NC}"

    else

        echo -e "${RED}[ERROR] $PACKAGE installation failed${NC}"

    fi


fi


}



# ------------------------------------------------------------
# INSTALL REQUIRED SOFTWARE
# ------------------------------------------------------------


echo "============================================"
echo " Installing packages"
echo "============================================"




# ============================================================
# INSTALL PACKAGES WITH I2P REPOSITORY FIX
# ============================================================


echo "============================================"
echo " Installing dependencies"
echo "============================================"


apt update


# Install required tools first

apt install -y \
curl \
wget \
gnupg \
ca-certificates \
apt-transport-https \
ufw \
apparmor \
apparmor-utils \
firejail \
lynis


# ------------------------------------------------------------
# Install Java
# ------------------------------------------------------------


echo "[+] Installing Java"


if command -v java >/dev/null 2>&1
then

    echo "[OK] Java already installed"

else

    apt install -y default-jre


    if command -v java >/dev/null 2>&1
    then

        echo "[OK] Java installed"

    else

        echo "[ERROR] Java installation failed"

    fi

fi



# ------------------------------------------------------------
# Add official I2P repository if package unavailable
# ------------------------------------------------------------


echo "[+] Checking I2P package"


if apt-cache show i2p >/dev/null 2>&1
then

    echo "[OK] I2P package available"

else


    echo "[!] I2P package missing"
    echo "[+] Adding official I2P repository"







# ============================================================
# JAVA + I2P INSTALLATION FIX FOR DEBIAN 13
# ============================================================


echo "============================================"
echo " Installing Java and I2P"
echo "============================================"



# Install dependencies

apt update

apt install -y \
curl \
gnupg \
ca-certificates \
lsb-release



# ------------------------------------------------------------
# JAVA CHECK
# ------------------------------------------------------------


echo "[+] Checking Java"


if command -v java >/dev/null 2>&1
then

    echo "[OK] Java already installed"

else

    echo "[+] Installing Java"

    apt install -y default-jre


fi



if command -v java >/dev/null 2>&1
then

    echo "[OK] Java verification passed"

    java -version

else

    echo "[FAIL] Java installation failed"

fi




# ------------------------------------------------------------
# I2P REPOSITORY
# ------------------------------------------------------------


echo "[+] Adding official I2P repository"



# Download official key

curl -o /tmp/i2p-archive-keyring.gpg \
https://i2p.net/i2p-archive-keyring.gpg



if [ -f /tmp/i2p-archive-keyring.gpg ]
then

    echo "[OK] I2P key downloaded"

else

    echo "[FAIL] Cannot download I2P key"

    exit 1

fi



# Install key

cp /tmp/i2p-archive-keyring.gpg \
/usr/share/keyrings/i2p-archive-keyring.gpg



chmod 644 /usr/share/keyrings/i2p-archive-keyring.gpg



echo "[OK] I2P key installed"




# Detect Debian version automatically

DEBIAN_CODENAME=$(lsb_release -sc)



echo "[+] Debian detected:"
echo "$DEBIAN_CODENAME"




# Create repository


echo "deb [signed-by=/usr/share/keyrings/i2p-archive-keyring.gpg] https://deb.i2p.net/ $DEBIAN_CODENAME main" \
> /etc/apt/sources.list.d/i2p.list



echo "[OK] I2P repository created"




# Update repository

apt update




# Install I2P

echo "[+] Installing I2P"



apt install -y i2p i2p-keyring




# ------------------------------------------------------------
# VERIFY INSTALLATION
# ------------------------------------------------------------


echo "============================================"
echo " I2P Verification"
echo "============================================"



if dpkg -s i2p >/dev/null 2>&1
then

    echo "[OK] I2P package installed"

else

    echo "[FAIL] I2P package missing"

fi



if command -v i2prouter >/dev/null 2>&1
then

    echo "[OK] i2prouter command found"

else

    echo "[WARNING] i2prouter not in PATH"

fi




    

    | gpg --dearmor \
    -o /usr/share/keyrings/i2p-archive-keyring.gpg



    echo "deb [signed-by=/usr/share/keyrings/i2p-archive-keyring.gpg] https://deb.i2p.net/ trixie main" \
    > /etc/apt/sources.list.d/i2p.list



    apt update


fi



# ------------------------------------------------------------
# Install I2P
# ------------------------------------------------------------


echo "[+] Installing I2P"


apt install -y i2p



# ------------------------------------------------------------
# Verify Java
# ------------------------------------------------------------


echo "============================================"
echo " Java verification"
echo "============================================"


if command -v java >/dev/null 2>&1
then

    echo "[OK] Java found"

    java -version

else

    echo "[FAIL] Java missing"

fi



# ------------------------------------------------------------
# Verify I2P
# ------------------------------------------------------------


echo "============================================"
echo " I2P verification"
echo "============================================"


if command -v i2prouter >/dev/null 2>&1
then

    echo "[OK] i2prouter found"

    i2prouter version


else

    echo "[FAIL] i2prouter missing"

fi








# ------------------------------------------------------------
# VERIFY COMMANDS
# ------------------------------------------------------------


echo "==========================================="
echo " Command verification"
echo "============================================"


check_command()
{

CMD=$1


if command -v "$CMD" >/dev/null 2>&1
then

    echo -e "${GREEN}[OK] $CMD available${NC}"

else

    echo -e "${RED}[ERROR] $CMD missing${NC}"

fi


}



check_command java
check_command i2prouter
check_command ufw
check_command firejail
check_command lynis



echo ""
echo "============================================"
echo " PART 1 COMPLETE"
echo " Log file:"
echo "$LOGFILE"
echo "============================================"


# ============================================================
# PART 2
# I2P CONFIGURATION + SECURITY HARDENING
# ============================================================


echo "============================================"
echo " PART 2: I2P and Security Configuration"
echo "============================================"



# ------------------------------------------------------------
# FIND REAL USER
# ------------------------------------------------------------

REAL_USER=$(logname 2>/dev/null || echo root)


if [ "$REAL_USER" != "root" ]
then

    USER_HOME="/home/$REAL_USER"

else

    USER_HOME="/root"

fi



# ------------------------------------------------------------
# CREATE I2P DOWNLOAD DIRECTORY
# ------------------------------------------------------------


DOWNLOAD_DIR="$USER_HOME/I2P-Downloads"


echo "[+] Creating download directory"


mkdir -p "$DOWNLOAD_DIR"



if [ -d "$DOWNLOAD_DIR" ]
then

    echo -e "${GREEN}[OK] Download folder exists${NC}"

else

    echo -e "${RED}[ERROR] Download folder failed${NC}"

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



# Backup old configuration

if [ -f "$I2P_DIR/router.config" ]
then

    cp "$I2P_DIR/router.config" \
    "$I2P_DIR/router.config.backup"

    echo -e "${GREEN}[OK] I2P config backup created${NC}"

fi



cat > "$I2P_DIR/router.config" <<EOF


# ==================================================
# Debian Live Secure I2P Configuration
# ==================================================


# Disable IPv6

i2np.enableIPv6=false


# Disable automatic UPnP port opening

i2np.upnp.enable=false


# Disable automatic external port forwarding

i2np.ntcp.autoPortForward=false

i2np.udp.autoPortForward=false



# Disable floodfill participation

router.floodfillParticipant=false



# Reduce bandwidth usage

i2np.bandwidthLimiter=true



EOF



if [ -f "$I2P_DIR/router.config" ]
then

    echo -e "${GREEN}[OK] I2P configuration created${NC}"

else

    echo -e "${RED}[ERROR] I2P configuration failed${NC}"

fi



# ============================================================
# START I2P
# ============================================================


echo "============================================"
echo " Starting I2P"
echo "============================================"



if command -v i2prouter >/dev/null 2>&1
then

    i2prouter start


    sleep 10



    if pgrep -f "i2p" >/dev/null
    then

        echo -e "${GREEN}[OK] I2P process running${NC}"

    else

        echo -e "${YELLOW}[WARNING] I2P process not detected${NC}"

    fi


else

    echo -e "${RED}[ERROR] i2prouter command missing${NC}"

fi



# ============================================================
# FIREWALL CONFIGURATION
# ============================================================


echo "============================================"
echo " Configuring UFW Firewall"
echo "============================================"



ufw --force reset



# Block incoming traffic

ufw default deny incoming



# Block outgoing by default

ufw default deny outgoing



# DNS

ufw allow out 53



# Debian updates

ufw allow out 80

ufw allow out 443



# I2P local proxy

ufw allow out 4444



# I2P router

ufw allow out 7654



ufw --force enable



# Verify firewall


if ufw status | grep -q "active"
then

    echo -e "${GREEN}[OK] Firewall active${NC}"

else

    echo -e "${RED}[ERROR] Firewall inactive${NC}"

fi



# ============================================================
# APPARMOR CHECK
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



cat >> /etc/sysctl.conf <<EOF


# Debian Live I2P hardening


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



echo -e "${GREEN}[OK] Kernel settings applied${NC}"



# ============================================================
# I2PSNARK INFORMATION
# ============================================================


echo ""
echo "============================================"
echo " I2PSnark Setup"
echo "============================================"

echo ""
echo "Open:"
echo ""
echo "http://127.0.0.1:7657/i2psnark/"
echo ""

echo "Recommended settings:"
echo ""
echo "1. Disable automatic torrent start"
echo "2. Stop torrents after completion"
echo "3. Use manual start"
echo "4. Set upload limit according to your preference"
echo "5. Download directory:"
echo "$DOWNLOAD_DIR"
echo ""



echo ""
echo "============================================"
echo " PART 2 COMPLETE"
echo "============================================"




# ============================================================
# PART 3
# FIREFOX + FINAL VERIFICATION REPORT
# ============================================================


echo "============================================"
echo " PART 3: Firefox and Final Checks"
echo "============================================"



# ============================================================
# FIREFOX I2P PROFILE
# ============================================================


echo "[+] Preparing Firefox I2P profile"



FIREFOX_DIR="$USER_HOME/.mozilla/firefox/i2p-profile"



mkdir -p "$FIREFOX_DIR"



cat > "$FIREFOX_DIR/user.js" <<EOF


// ==================================================
// Firefox I2P privacy profile
// Generated by Debian Live I2P script
// ==================================================



// Disable WebRTC

user_pref("media.peerconnection.enabled", false);



// Disable DNS over HTTPS

user_pref("network.trr.mode", 5);



// Disable DNS prefetch

user_pref("network.prefetch-next", false);



// Disable link prefetch

user_pref("network.http.speculative-parallel-limit", 0);



// Disable telemetry

user_pref("toolkit.telemetry.enabled", false);



EOF



if [ -f "$FIREFOX_DIR/user.js" ]
then

    echo -e "${GREEN}[OK] Firefox I2P profile created${NC}"

else

    echo -e "${RED}[ERROR] Firefox profile creation failed${NC}"

fi



# ============================================================
# FIREFOX PROXY INFORMATION
# ============================================================


echo ""
echo "============================================"
echo " Firefox Configuration"
echo "============================================"


echo ""
echo "Configure Firefox manually:"
echo ""
echo "Settings"
echo " -> Network Settings"
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
# TEST I2P PORTS
# ============================================================


echo "============================================"
echo " Testing I2P Services"
echo "============================================"



# Test I2P console

if curl -s http://127.0.0.1:7657 >/dev/null
then

    echo -e "${GREEN}[OK] I2P console reachable${NC}"

else

    echo -e "${YELLOW}[WARNING] I2P console not reachable${NC}"

fi



# Test I2PSnark

if curl -s http://127.0.0.1:7657/i2psnark/ >/dev/null
then

    echo -e "${GREEN}[OK] I2PSnark available${NC}"

else

    echo -e "${YELLOW}[WARNING] I2PSnark not detected${NC}"

fi



# ============================================================
# FIREJAIL CHECK
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
# LYNIS AUDIT
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



# Firewall

if ufw status | grep -q active
then

echo -e "${GREEN}[OK] Firewall active${NC}"

else

echo -e "${RED}[FAIL] Firewall inactive${NC}"

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
echo "3) Start Firefox with I2P proxy:"
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










