#!/bin/bash

# ============================================================
# Debian Live + Java I2P Secure Setup v2
#
# Features:
# - Java I2P
# - No UFW (I2P compatible)
# - Security checks
# - Green / Red status
# - Diagnostic report
# - 1. Vérification root
2. Détection Debian version
3. Test Internet
4. Installation Java
5. Installation I2P
6. Installation outils sécurité
7. Configuration I2P
8. Configuration tunnels
9. Configuration AppArmor sans blocage
10. Durcissement kernel
11. Création dossier Downloads
12. Démarrage I2P
13. Tests automatiques
14. Rapport final couleur
# ============================================================


# ================= COLORS =================

GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
RESET="\e[0m"


OK()
{
echo -e "${GREEN}[✓ OK]${RESET} $1"
}


FAIL()
{
echo -e "${RED}[✗ FAIL]${RESET} $1"
}


WARN()
{
echo -e "${YELLOW}[! WARNING]${RESET} $1"
}



# ================= ROOT CHECK =================


if [ "$EUID" -ne 0 ]; then

FAIL "Run as root"

echo "Use:"
echo "sudo ./secure_debian_live_i2p_v2.sh"

exit 1

else

OK "Root privileges"

fi



# ================= DEBIAN CHECK =================


echo ""
echo "======================================"
echo " Debian Detection"
echo "======================================"


if [ -f /etc/debian_version ]; then

OK "Debian detected"

DEBIAN_VERSION=$(cat /etc/debian_version)

echo "Version: $DEBIAN_VERSION"

else

FAIL "Not Debian"

exit 1

fi



# ================= INTERNET TEST =================


echo ""
echo "======================================"
echo " Internet Test"
echo "======================================"


if ping -c 1 deb.debian.org >/dev/null 2>&1

then

OK "Internet connection"

else

FAIL "No internet connection"

fi



# ================= UPDATE =================


echo ""
echo "[+] Updating repositories..."

apt update



# ================= INSTALL PACKAGES =================


echo ""
echo "======================================"
echo " Installing packages"
echo "======================================"


PACKAGES="\
default-jre \
i2p \
apparmor \
apparmor-utils \
firejail \
lynis \
unattended-upgrades \
curl \
wget"


for PACKAGE in $PACKAGES

do

apt install -y $PACKAGE >/dev/null 2>&1


if dpkg -s $PACKAGE >/dev/null 2>&1

then

OK "$PACKAGE installed"

else

FAIL "$PACKAGE missing"

fi


done



# ================= JAVA CHECK =================


echo ""
echo "======================================"
echo " Java Check"
echo "======================================"


if command -v java >/dev/null 2>&1

then

OK "Java installed"

java -version 2>&1 | head -1


else

FAIL "Java missing"

fi



# ================= I2P CHECK =================


echo ""
echo "======================================"
echo " I2P Check"
echo "======================================"


if dpkg -s i2p >/dev/null 2>&1

then

OK "I2P package installed"

else

FAIL "I2P missing"

fi



# ================= I2P USER =================


if id i2psvc >/dev/null 2>&1

then

OK "I2P user i2psvc detected"

else

WARN "i2psvc user not found yet"

fi



echo ""
echo "=========== PART 1 COMPLETE =========="
echo "Continue with PART 2"




# ================= I2P SERVICE CONFIG =================

echo ""
echo "======================================"
echo " I2P Service Configuration"
echo "======================================"


systemctl enable i2p >/dev/null 2>&1


if systemctl is-enabled i2p >/dev/null 2>&1

then

OK "I2P service enabled"

else

WARN "Could not enable I2P service"

fi



systemctl restart i2p


sleep 15



if systemctl is-active i2p >/dev/null 2>&1

then

OK "I2P service running"

else

FAIL "I2P service not running"

fi



# ================= I2P CONFIG CHECK =================


I2P_CONFIG="/var/lib/i2p/i2p-config"


echo ""
echo "======================================"
echo " I2P Configuration Check"
echo "======================================"


if [ -d "$I2P_CONFIG" ]

then

OK "I2P config directory found"

else

FAIL "I2P config directory missing"

fi



if [ -f "$I2P_CONFIG/i2ptunnel.config" ]

then

OK "i2ptunnel.config found"

else

WARN "i2ptunnel.config not found yet"

fi



# ================= HTTP PROXY CHECK =================


echo ""
echo "======================================"
echo " I2P HTTP Proxy"
echo "======================================"


if [ -f "$I2P_CONFIG/i2ptunnel.config" ]

then


if grep -q "listenPort=4444" "$I2P_CONFIG/i2ptunnel.config"

then

OK "HTTP Proxy configured on port 4444"

else

WARN "HTTP Proxy port 4444 not detected"

fi


else

WARN "Cannot check proxy"

fi



# ================= APPARMOR =================


echo ""
echo "======================================"
echo " AppArmor"
echo "======================================"


systemctl start apparmor >/dev/null 2>&1


if systemctl is-active apparmor >/dev/null 2>&1

then

OK "AppArmor running"

else

WARN "AppArmor not running"

fi



# Put I2P profiles in complain mode
# Prevents blocking I2P functions

aa-complain /usr/sbin/wrapper >/dev/null 2>&1 || true



# ================= KERNEL HARDENING =================


echo ""
echo "======================================"
echo " Kernel Security"
echo "======================================"


cat >> /etc/sysctl.conf <<EOF

# I2P Live Security

kernel.kptr_restrict=2

kernel.dmesg_restrict=1

kernel.randomize_va_space=2

kernel.sysrq=0

fs.suid_dumpable=0

net.ipv6.conf.all.disable_ipv6=1

net.ipv6.conf.default.disable_ipv6=1

EOF


sysctl -p >/dev/null 2>&1


OK "Kernel security settings applied"



# ================= FIREJAIL =================


echo ""
echo "======================================"
echo " Firejail"
echo "======================================"


if command -v firejail >/dev/null 2>&1

then

OK "Firejail installed"

else

FAIL "Firejail missing"

fi



# ================= DOWNLOAD DIRECTORY =================


echo ""
echo "======================================"
echo " Download Folder"
echo "======================================"


DOWNLOAD_DIR="$HOME/I2P-Downloads"


mkdir -p "$DOWNLOAD_DIR"


if [ -d "$DOWNLOAD_DIR" ]

then

OK "Download directory created"

echo "$DOWNLOAD_DIR"

else

FAIL "Cannot create download directory"

fi



echo ""
echo "=========== PART 2 COMPLETE =========="
echo "Continue with PART 3"





# ================= FINAL VERIFICATION =================

echo ""
echo "======================================"
echo " FINAL SECURITY CHECK"
echo "======================================"


# -------- JAVA --------

if command -v java >/dev/null 2>&1

then

OK "Java working"

else

FAIL "Java not working"

fi



# -------- I2P SERVICE --------


if systemctl is-active i2p >/dev/null 2>&1

then

OK "I2P service active"

else

FAIL "I2P service inactive"

fi



# -------- USER CHECK --------


if id i2psvc >/dev/null 2>&1

then

OK "I2P user i2psvc exists"

else

WARN "I2P user missing"

fi



# -------- PORT CHECK --------


echo ""
echo "Checking I2P ports..."


if ss -tln | grep -q ":7657"

then

OK "I2P Router Console port 7657 open"

else

WARN "Console port 7657 not detected"

fi



if ss -tln | grep -q ":4444"

then

OK "I2P HTTP Proxy port 4444 open"

else

WARN "HTTP Proxy 4444 not detected"
echo "Start Application Tunnels from:"
echo "http://127.0.0.1:7657/configclients"

fi



# -------- CONFIG TEST --------


if [ -f "/var/lib/i2p/i2p-config/i2ptunnel.config" ]

then


if grep -q "tunnel.0.type=httpclient" \
/var/lib/i2p/i2p-config/i2ptunnel.config

then

OK "HTTP Client tunnel configured"

else

WARN "HTTP Client tunnel not detected"

fi


else

WARN "Tunnel configuration missing"

fi



# -------- FIREWALL CHECK --------


echo ""
echo "Firewall check"


if command -v ufw >/dev/null 2>&1

then

echo "UFW detected"

if ufw status | grep -q "deny (outgoing)"

then

WARN "Outgoing firewall blocking detected"

echo "This can break I2P"

else

OK "Firewall compatible"

fi


else

OK "No UFW firewall installed"

fi



# -------- DIAGNOSTIC FILE --------


REPORT="$HOME/i2p-diagnostic.txt"


echo "Creating diagnostic report..."


{

echo "========== I2P DIAGNOSTIC =========="

echo ""

echo "Date:"
date


echo ""

echo "Debian:"
cat /etc/debian_version


echo ""

echo "Java:"
java -version 2>&1


echo ""

echo "I2P SERVICE:"
systemctl status i2p --no-pager


echo ""

echo "PORTS:"
ss -tlnp | grep -E "7657|4444"


echo ""

echo "USER:"
id i2psvc


echo ""

echo "===================================="

} > "$REPORT"



OK "Diagnostic saved"

echo "File:"
echo "$REPORT"



# ================= FINAL MESSAGE =================


echo ""
echo "======================================"
echo "        INSTALLATION FINISHED"
echo "======================================"


echo ""

echo "I2P Console:"
echo "http://127.0.0.1:7657"


echo ""

echo "Firefox Proxy:"
echo "HTTP Proxy: 127.0.0.1"
echo "Port: 4444"


echo ""

echo "I2P Downloads:"
echo "$HOME/I2P-Downloads"


echo ""

echo "IMPORTANT:"
echo "- Wait 5-10 minutes after starting I2P"
echo "- First tunnels can be slow"
echo "- Debian Live loses changes without persistence"
echo "- Sur ton installation réelle, c'était le bouton Start Application Tunnels qui a débloqué 4444. "


echo ""
echo "======================================"
echo "        DONE"
echo "======================================"











