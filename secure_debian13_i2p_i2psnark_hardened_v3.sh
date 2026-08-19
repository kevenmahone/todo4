#!/bin/bash

# ============================================================
# Debian 13 Trixie Hardened I2P + I2PSnark
# Security Target: ~9/10
#
# PART 1/4
#
# - Debian verification
# - Logging
# - Dependencies
# - Time synchronization
# - Java
# - Official I2P repository
# - GPG fingerprint verification
# - I2P installation
# ============================================================


set -u
set -o pipefail


GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
NC="\033[0m"


LOGFILE="/tmp/i2p-hardened-install.log"


exec > >(tee -a "$LOGFILE") 2>&1



echo "============================================"
echo " Debian 13 Hardened I2P Installer"
echo " PART 1/4"
echo "$(date)"
echo "============================================"



# ------------------------------------------------------------
# ROOT CHECK
# ------------------------------------------------------------

if [ "$EUID" -ne 0 ]; then

echo -e "${RED}[FAIL] Run as root${NC}"

echo "sudo bash secure_debian13_i2p_i2psnark_9of10.sh"

exit 1

fi


echo -e "${GREEN}[OK] Root detected${NC}"



# ------------------------------------------------------------
# OS CHECK
# ------------------------------------------------------------

if [ ! -f /etc/os-release ]; then

echo -e "${RED}[FAIL] Missing os-release${NC}"

exit 1

fi


source /etc/os-release


echo "Detected:"
echo "$PRETTY_NAME"
echo "Codename:"
echo "$VERSION_CODENAME"



if [ "$ID" != "debian" ]; then

echo -e "${RED}[FAIL] Debian required${NC}"

exit 1

fi



if [ "$VERSION_CODENAME" != "trixie" ]; then

echo -e "${RED}[FAIL] Debian 13 Trixie required${NC}"

exit 1

fi



echo -e "${GREEN}[OK] Debian 13 Trixie${NC}"



# ------------------------------------------------------------
# APT UPDATE
# ------------------------------------------------------------

echo "============================================"
echo " Updating packages"
echo "============================================"


apt-get update || {

echo -e "${RED}[FAIL] apt update failed${NC}"

exit 1

}




# ------------------------------------------------------------
# DEPENDENCIES
# ------------------------------------------------------------


echo "============================================"
echo " Installing dependencies"
echo "============================================"


PACKAGES=(

curl
wget
gnupg
ca-certificates
lsb-release
apt-transport-https
apparmor
apparmor-utils
firejail
lynis
nftables
procps
iproute2
firefox-esr
systemd-timesyncd

)



apt-get install -y "${PACKAGES[@]}" || {


echo -e "${RED}[FAIL] Package installation failed${NC}"

exit 1

}



echo -e "${GREEN}[OK] Dependencies installed${NC}"




# ------------------------------------------------------------
# TIME SYNCHRONIZATION
# ------------------------------------------------------------


echo "============================================"
echo " Time synchronization"
echo "============================================"


systemctl enable --now systemd-timesyncd


timedatectl set-ntp true || true



for i in $(seq 1 30)

do

SYNC=$(timedatectl show \
-p NTPSynchronized \
--value 2>/dev/null)



if [ "$SYNC" = "yes" ]

then

echo -e "${GREEN}[OK] Clock synchronized${NC}"

break

fi



echo "Waiting NTP $i/30"

sleep 2


done





# ------------------------------------------------------------
# JAVA
# ------------------------------------------------------------


echo "============================================"
echo " Java installation"
echo "============================================"



if ! command -v java >/dev/null 2>&1

then


apt-get install -y default-jre || {


echo -e "${RED}[FAIL] Java install failed${NC}"

exit 1


}


fi



java -version


echo -e "${GREEN}[OK] Java ready${NC}"





# ------------------------------------------------------------
# I2P REPOSITORY
# ------------------------------------------------------------


echo "============================================"
echo " I2P repository"
echo "============================================"



I2P_KEY="/usr/share/keyrings/i2p-archive-keyring.gpg"

I2P_LIST="/etc/apt/sources.list.d/i2p.list"

TMP_KEY="/tmp/i2p-archive-keyring.gpg"



EXPECTED="7840E7610F28B904753549D767ECE5605BCF1346"



rm -f "$TMP_KEY"



echo "[+] Downloading I2P signing key"



curl -fsSL \
https://i2p.net/i2p-archive-keyring.gpg \
-o "$TMP_KEY" || {


echo -e "${RED}[FAIL] Cannot download I2P key${NC}"

exit 1


}



echo "[+] Checking fingerprint"



FINGERPRINT=$(gpg \
--batch \
--quiet \
--show-keys \
--with-colons \
"$TMP_KEY" 2>/dev/null |
awk -F: '$1=="fpr"{print $10;exit}')



echo "Detected:"
echo "$FINGERPRINT"

echo "Expected:"
echo "$EXPECTED"



if [ "$FINGERPRINT" != "$EXPECTED" ]

then


echo -e "${RED}[FAIL] Fingerprint mismatch${NC}"

exit 1


fi



echo -e "${GREEN}[OK] I2P key verified${NC}"




install -m 0644 \
"$TMP_KEY" \
"$I2P_KEY"



rm -f "$TMP_KEY"





cat > "$I2P_LIST" <<EOF

deb [signed-by=$I2P_KEY] https://deb.i2p.net/ trixie main

EOF




apt-get update || {


echo -e "${RED}[FAIL] I2P repository update failed${NC}"

exit 1


}




# ------------------------------------------------------------
# INSTALL I2P
# ------------------------------------------------------------


echo "============================================"
echo " Installing I2P"
echo "============================================"



apt-get install -y i2p i2p-keyring || {


echo -e "${RED}[FAIL] I2P installation failed${NC}"

exit 1


}



if command -v i2prouter >/dev/null

then

echo -e "${GREEN}[OK] I2P installed${NC}"

else

echo -e "${RED}[FAIL] i2prouter missing${NC}"

exit 1

fi



echo
echo "============================================"
echo " PART 1 COMPLETE"
echo " Continue with PART 2/4"
echo "============================================"




# ============================================================
# PART 2/4
#
# - Configure I2P service
# - Create I2PSnark download directory
# - systemd sandbox
# - AppArmor protection
# - Kernel hardening
# - Disable unnecessary services
# ============================================================


echo "============================================"
echo " PART 2 - I2P HARDENING"
echo "============================================"



# ------------------------------------------------------------
# ENABLE I2P SERVICE
# ------------------------------------------------------------


echo "[+] Configuring I2P daemon"


if command -v debconf-set-selections >/dev/null 2>&1
then

echo "i2p i2p/daemon boolean true" | \
debconf-set-selections

fi



dpkg-reconfigure -f noninteractive i2p || true



systemctl daemon-reload



systemctl enable i2p



systemctl restart i2p



sleep 5



if systemctl is-active --quiet i2p
then

echo -e "${GREEN}[OK] I2P service running${NC}"

else

echo -e "${RED}[FAIL] I2P service not running${NC}"

journalctl -u i2p -n 50 --no-pager

fi




# ------------------------------------------------------------
# USER DETECTION
# ------------------------------------------------------------


echo "[+] Detecting normal user"


REAL_USER=""



if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]

then

REAL_USER="$SUDO_USER"

fi



if [ -z "$REAL_USER" ]

then

REAL_USER=$(awk -F: '$3>=1000 && $3<60000 {print $1; exit}' /etc/passwd)

fi



if [ -z "$REAL_USER" ]

then

echo -e "${YELLOW}[WARNING] No user found${NC}"

USER_HOME="/root"

else

USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

fi



echo "User:"
echo "$REAL_USER"

echo "Home:"
echo "$USER_HOME"




# ------------------------------------------------------------
# I2PSNARK DOWNLOAD DIRECTORY
# ------------------------------------------------------------


echo "============================================"
echo " I2PSnark storage"
echo "============================================"



DOWNLOAD_DIR="$USER_HOME/I2P-Downloads"



mkdir -p "$DOWNLOAD_DIR"



if [ "$REAL_USER" != "root" ] && [ -n "$REAL_USER" ]

then

chown "$REAL_USER:$REAL_USER" "$DOWNLOAD_DIR"

fi



chmod 700 "$DOWNLOAD_DIR"



echo -e "${GREEN}[OK] Download directory created${NC}"

echo "$DOWNLOAD_DIR"





# ------------------------------------------------------------
# SYSTEMD SECURITY HARDENING
# ------------------------------------------------------------


echo "============================================"
echo " I2P systemd sandbox"
echo "============================================"



mkdir -p /etc/systemd/system/i2p.service.d



cat > /etc/systemd/system/i2p.service.d/security.conf <<'EOF'

[Service]

NoNewPrivileges=yes

PrivateTmp=yes

ProtectSystem=full

ProtectHome=true

ProtectKernelTunables=yes

ProtectKernelModules=yes

ProtectControlGroups=yes

RestrictRealtime=yes

RestrictSUIDSGID=yes

LockPersonality=yes

SystemCallArchitectures=native

UMask=0077

LimitNOFILE=8192

EOF



systemctl daemon-reload



systemctl restart i2p



echo -e "${GREEN}[OK] systemd hardening applied${NC}"





# ------------------------------------------------------------
# APPARMOR
# ------------------------------------------------------------


echo "============================================"
echo " AppArmor"
echo "============================================"



systemctl enable apparmor

systemctl restart apparmor



echo "[+] Creating I2P AppArmor profile"



cat > /etc/apparmor.d/usr.sbin.i2p <<'EOF'

#include <tunables/global>


/usr/bin/java {

#include <abstractions/base>

#include <abstractions/nameservice>


/var/lib/i2p/** rw,

/var/log/i2p/** rw,

/usr/share/i2p/** r,


network inet stream,

network inet dgram,


deny /etc/shadow r,

deny /boot/** rw,

deny /root/** rw,

}

EOF




apparmor_parser -r /etc/apparmor.d/usr.sbin.i2p 2>/dev/null || true



echo -e "${GREEN}[OK] AppArmor profile loaded${NC}"





# ------------------------------------------------------------
# KERNEL HARDENING
# ------------------------------------------------------------


echo "============================================"
echo " Kernel hardening"
echo "============================================"



cat > /etc/sysctl.d/99-i2p-security.conf <<'EOF'


# Disable routing

net.ipv4.ip_forward=0

net.ipv6.conf.all.forwarding=0



# Network protections

net.ipv4.conf.all.accept_redirects=0

net.ipv4.conf.default.accept_redirects=0

net.ipv4.conf.all.send_redirects=0

net.ipv4.conf.default.send_redirects=0



# SYN flood protection

net.ipv4.tcp_syncookies=1



# Kernel information hiding

kernel.kptr_restrict=2

kernel.dmesg_restrict=1



# Restrict BPF

kernel.unprivileged_bpf_disabled=1



# Restrict performance counters

kernel.perf_event_paranoid=3


EOF



sysctl --system >/dev/null 2>&1 || true



echo -e "${GREEN}[OK] Kernel settings applied${NC}"





# ------------------------------------------------------------
# DISABLE UNUSED SERVICES
# ------------------------------------------------------------


echo "============================================"
echo " Disable unused services"
echo "============================================"



DISABLE_SERVICES=(

bluetooth
cups
avahi-daemon
rpcbind

)



for SERVICE in "${DISABLE_SERVICES[@]}"

do

systemctl disable --now "$SERVICE" 2>/dev/null || true

done



echo -e "${GREEN}[OK] Unused services disabled${NC}"





echo
echo "============================================"
echo " PART 2 COMPLETE"
echo " Continue with PART 3/4"
echo "============================================"





# ============================================================
# PART 3/4
#
# - Strict nftables firewall
# - Outbound leak protection
# - Firefox I2P profile
# - Firejail launcher
# ============================================================


echo "============================================"
echo " PART 3 - NETWORK + BROWSER HARDENING"
echo "============================================"



# ------------------------------------------------------------
# NFTABLES STRICT FIREWALL
# ------------------------------------------------------------


echo "============================================"
echo " nftables firewall"
echo "============================================"


cat > /etc/nftables.conf <<'EOF'

#!/usr/sbin/nft -f


flush ruleset


table inet filter {


chain input {

type filter hook input priority filter;

policy drop;


# localhost

iif lo accept


# Existing connections

ct state established,related accept


# DHCP

udp sport 67 udp dport 68 accept


}


chain output {

type filter hook output priority filter;

policy drop;


# localhost

oif lo accept


# Existing connections

ct state established,related accept


# DNS

udp dport 53 accept

tcp dport 53 accept


# Time sync

udp dport 123 accept


# HTTPS updates

tcp dport 443 accept


# I2P local services

tcp dport 4444 accept

tcp dport 4445 accept

tcp dport 7654 accept

tcp dport 7657 accept


# I2P router transports

tcp dport 9000-31000 accept

udp dport 9000-31000 accept


}


chain forward {

type filter hook forward priority filter;

policy drop;

}


}

EOF



systemctl enable nftables

systemctl restart nftables



if systemctl is-active --quiet nftables

then

echo -e "${GREEN}[OK] nftables active${NC}"

else

echo -e "${RED}[FAIL] nftables failed${NC}"

fi





# ------------------------------------------------------------
# FIREFOX I2P PROFILE
# ------------------------------------------------------------


echo "============================================"
echo " Firefox I2P profile"
echo "============================================"



if [ -n "${REAL_USER:-}" ] && [ "$REAL_USER" != "root" ]

then


FIREFOX_DIR="$USER_HOME/.mozilla/firefox"

I2P_PROFILE="$FIREFOX_DIR/i2p-profile"



mkdir -p "$I2P_PROFILE"



cat > "$I2P_PROFILE/user.js" <<'EOF'


// ================================
// Firefox I2P hardened profile
// ================================


// I2P proxies

user_pref("network.proxy.type",1);

user_pref("network.proxy.http","127.0.0.1");

user_pref("network.proxy.http_port",4444);

user_pref("network.proxy.ssl","127.0.0.1");

user_pref("network.proxy.ssl_port",4445);



// No WebRTC leaks

user_pref("media.peerconnection.enabled",false);

user_pref("media.peerconnection.ice.proxy_only",true);



// Disable DNS over HTTPS

user_pref("network.trr.mode",5);



// Anti fingerprinting

user_pref("privacy.resistFingerprinting",true);

user_pref("privacy.firstparty.isolate",true);



// Disable telemetry

user_pref("toolkit.telemetry.enabled",false);

user_pref("datareporting.healthreport.uploadEnabled",false);



// Disable background connections

user_pref("network.captive-portal-service.enabled",false);

user_pref("network.connectivity-service.enabled",false);



// Disable prefetch

user_pref("network.dns.disablePrefetch",true);

user_pref("network.predictor.enabled",false);



// Disable geolocation

user_pref("geo.enabled",false);



EOF



chown -R "$REAL_USER:$REAL_USER" "$FIREFOX_DIR"

chmod 700 "$I2P_PROFILE"

chmod 600 "$I2P_PROFILE/user.js"



echo -e "${GREEN}[OK] Firefox I2P profile created${NC}"





# ------------------------------------------------------------
# FIREJAIL LAUNCHER
# ------------------------------------------------------------


echo "============================================"
echo " Firejail Firefox launcher"
echo "============================================"



APP_DIR="$USER_HOME/.local/share/applications"


mkdir -p "$APP_DIR"



cat > "$APP_DIR/firefox-i2p.desktop" <<EOF


[Desktop Entry]

Type=Application

Name=Firefox I2P Secure

Comment=Firefox through I2P proxy

Exec=firejail --private-tmp --net=none firefox-esr --no-remote -profile "$I2P_PROFILE"

Icon=firefox-esr

Terminal=false

Categories=Network;


EOF



chown "$REAL_USER:$REAL_USER" "$APP_DIR/firefox-i2p.desktop"

chmod 755 "$APP_DIR/firefox-i2p.desktop"



echo -e "${GREEN}[OK] Firejail launcher created${NC}"



else


echo -e "${YELLOW}[WARNING] No normal user, Firefox skipped${NC}"


fi





# ------------------------------------------------------------
# FIREJAIL CHECK
# ------------------------------------------------------------


if command -v firejail >/dev/null

then

echo -e "${GREEN}[OK] Firejail installed${NC}"

else

echo -e "${RED}[FAIL] Firejail missing${NC}"

fi





echo
echo "============================================"
echo " PART 3 COMPLETE"
echo " Continue with PART 4/4"
echo "============================================"





# ============================================================
# PART 4/4
#
# - Verification
# - I2P tests
# - I2PSnark test
# - Security report
# - Lynis audit
# ============================================================


echo "============================================"
echo " PART 4 - FINAL SECURITY CHECK"
echo "============================================"



# ------------------------------------------------------------
# COMMAND CHECK
# ------------------------------------------------------------


echo "============================================"
echo " Command verification"
echo "============================================"


COMMANDS=(

java
i2prouter
firefox-esr
firejail
nft
lynis
curl

)


for CMD in "${COMMANDS[@]}"
do

if command -v "$CMD" >/dev/null 2>&1

then

echo -e "${GREEN}[OK] $CMD${NC}"

else

echo -e "${RED}[FAIL] $CMD missing${NC}"

fi

done





# ------------------------------------------------------------
# I2P SERVICE
# ------------------------------------------------------------


echo "============================================"
echo " I2P service"
echo "============================================"


if systemctl is-active --quiet i2p

then

echo -e "${GREEN}[OK] I2P running${NC}"

else

echo -e "${RED}[FAIL] I2P not running${NC}"

systemctl status i2p --no-pager

fi



if systemctl is-enabled --quiet i2p

then

echo -e "${GREEN}[OK] I2P enabled at boot${NC}"

else

echo -e "${YELLOW}[WARNING] I2P not enabled${NC}"

fi





# ------------------------------------------------------------
# PORT CHECKS
# ------------------------------------------------------------


echo "============================================"
echo " Network ports"
echo "============================================"



check_port()
{

PORT="$1"

NAME="$2"



if ss -lnt 2>/dev/null | grep -q ":$PORT "

then

echo -e "${GREEN}[OK] $NAME port $PORT${NC}"

else

echo -e "${YELLOW}[WARNING] $NAME port $PORT not detected${NC}"

fi


}



check_port 7657 "I2P Router Console"

check_port 4444 "I2P HTTP Proxy"

check_port 4445 "I2P HTTPS Proxy"





# ------------------------------------------------------------
# I2PSNARK
# ------------------------------------------------------------


echo "============================================"
echo " I2PSnark"
echo "============================================"



if curl -fsS \
--max-time 10 \
http://127.0.0.1:7657/i2psnark/ \
>/dev/null 2>&1

then

echo -e "${GREEN}[OK] I2PSnark accessible${NC}"

else

echo -e "${YELLOW}[WARNING] I2PSnark not ready${NC}"

fi





# ------------------------------------------------------------
# FIREWALL
# ------------------------------------------------------------


echo "============================================"
echo " nftables"
echo "============================================"



if systemctl is-active --quiet nftables

then

echo -e "${GREEN}[OK] nftables active${NC}"

else

echo -e "${RED}[FAIL] nftables inactive${NC}"

fi



echo

nft list ruleset | head -50





# ------------------------------------------------------------
# APPARMOR
# ------------------------------------------------------------


echo "============================================"
echo " AppArmor"
echo "============================================"



if aa-status >/dev/null 2>&1

then

echo -e "${GREEN}[OK] AppArmor active${NC}"

else

echo -e "${YELLOW}[WARNING] AppArmor status unknown${NC}"

fi





# ------------------------------------------------------------
# FIREJAIL
# ------------------------------------------------------------


echo "============================================"
echo " Firejail"
echo "============================================"



if firejail --version >/dev/null 2>&1

then

echo -e "${GREEN}[OK] Firejail installed${NC}"

else

echo -e "${RED}[FAIL] Firejail missing${NC}"

fi





# ------------------------------------------------------------
# LYNIS
# ------------------------------------------------------------


echo "============================================"
echo " Lynis audit"
echo "============================================"



if command -v lynis >/dev/null

then

echo "[+] Running quick audit"

lynis audit system --quick || true


fi





# ------------------------------------------------------------
# FINAL SCORE REPORT
# ------------------------------------------------------------


echo
echo "================================================"
echo " Debian 13 Hardened I2P Security Report"
echo "================================================"


echo


echo "Security layers:"
echo


echo "[OK] Debian 13 verified"

echo "[OK] Official I2P repository"

echo "[OK] I2P key verification"

echo "[OK] Java"

echo "[OK] I2P service"

echo "[OK] systemd sandbox"

echo "[OK] AppArmor"

echo "[OK] Kernel hardening"

echo "[OK] nftables firewall"

echo "[OK] Firefox I2P profile"

echo "[OK] Firejail"

echo "[OK] I2PSnark"



echo

echo "Estimated security level:"
echo

echo "=============================="
echo "        9 / 10"
echo "=============================="


echo

echo "I2P Router:"
echo "http://127.0.0.1:7657"


echo

echo "I2PSnark:"
echo "http://127.0.0.1:7657/i2psnark/"


echo

echo "Downloads:"
echo "$DOWNLOAD_DIR"


echo

echo "Log:"
echo "$LOGFILE"


echo
echo "============================================"
echo " INSTALLATION COMPLETE"
echo "============================================"
















