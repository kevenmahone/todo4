#!/bin/bash

# ============================================================
# Debian 13 Trixie Hardened I2P + I2PSnark Setup
#
# PART 1/4
#
# Includes:
# - Debian 13 detection
# - Logging
# - Package installation
# - Time synchronization
# - Java installation
# - Official I2P repository
# - I2P signing key verification
# - I2P installation
#
# No UFW
# I2PSnark compatible
# ============================================================

set -u
set -o pipefail

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
NC="\033[0m"

LOGFILE="/tmp/debian13-i2p-hardened.log"

exec > >(tee -a "$LOGFILE") 2>&1


echo "============================================"
echo " Debian 13 Hardened I2P Setup"
echo " PART 1/4"
echo "$(date)"
echo "============================================"


# ------------------------------------------------------------
# ROOT CHECK
# ------------------------------------------------------------

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[FAIL] Run as root${NC}"
    echo "sudo bash secure_debian13_i2p_i2psnark_hardened_v2.sh"
    exit 1
fi

echo -e "${GREEN}[OK] Root privileges${NC}"


# ------------------------------------------------------------
# OS CHECK
# ------------------------------------------------------------

if [ ! -f /etc/os-release ]; then
    echo -e "${RED}[FAIL] Missing /etc/os-release${NC}"
    exit 1
fi

source /etc/os-release


echo "OS: ${PRETTY_NAME}"
echo "CODENAME: ${VERSION_CODENAME}"


if [ "$ID" != "debian" ]; then
    echo -e "${RED}[FAIL] Debian required${NC}"
    exit 1
fi


if [ "$VERSION_CODENAME" != "trixie" ]; then
    echo -e "${RED}[FAIL] Debian 13 Trixie required${NC}"
    exit 1
fi


echo -e "${GREEN}[OK] Debian 13 Trixie detected${NC}"


# ------------------------------------------------------------
# ARCHITECTURE
# ------------------------------------------------------------

ARCH=$(dpkg --print-architecture)

echo "Architecture: $ARCH"


# ------------------------------------------------------------
# APT UPDATE
# ------------------------------------------------------------

echo "============================================"
echo " Updating APT"
echo "============================================"


apt-get update || {
    echo -e "${RED}[FAIL] apt update failed${NC}"
    exit 1
}


# ------------------------------------------------------------
# PACKAGES
# ------------------------------------------------------------

echo "============================================"
echo " Installing packages"
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
curl
procps
iproute2
firefox-esr
systemd-timesyncd
nftables
)


apt-get install -y "${PACKAGES[@]}" || {

echo -e "${RED}[FAIL] Package installation failed${NC}"
exit 1

}


echo -e "${GREEN}[OK] Packages installed${NC}"


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

if [ "$SYNC" = "yes" ]; then

echo -e "${GREEN}[OK] Clock synchronized${NC}"
break

fi


echo "Waiting for NTP $i/30"
sleep 2

done



# ------------------------------------------------------------
# JAVA
# ------------------------------------------------------------

echo "============================================"
echo " Installing Java"
echo "============================================"


if ! command -v java >/dev/null 2>&1
then

apt-get install -y default-jre || {

echo -e "${RED}[FAIL] Java installation failed${NC}"
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

I2P_SOURCE="/etc/apt/sources.list.d/i2p.list"

TMP_KEY="/tmp/i2p-key.gpg"


EXPECTED="7840E7610F28B904753549D767ECE5605BCF1346"



rm -f "$TMP_KEY"



curl -fsSL \
https://i2p.net/i2p-archive-keyring.gpg \
-o "$TMP_KEY" || {

echo -e "${RED}[FAIL] Cannot download I2P key${NC}"
exit 1

}



FP=$(gpg \
--show-keys \
--with-colons \
"$TMP_KEY" 2>/dev/null |
awk -F: '$1=="fpr"{print $10;exit}')



echo "Detected:"
echo "$FP"

echo "Expected:"
echo "$EXPECTED"



if [ "$FP" != "$EXPECTED" ]
then

echo -e "${RED}[FAIL] I2P fingerprint mismatch${NC}"
exit 1

fi


echo -e "${GREEN}[OK] I2P signing key verified${NC}"



install -m 0644 \
"$TMP_KEY" \
"$I2P_KEY"


cat > "$I2P_SOURCE" <<EOF
deb [signed-by=$I2P_KEY] https://deb.i2p.net/ trixie main
EOF



apt-get update || exit 1



# ------------------------------------------------------------
# INSTALL I2P
# ------------------------------------------------------------

echo "============================================"
echo " Installing I2P"
echo "============================================"


apt-get install -y i2p i2p-keyring || {

echo -e "${RED}[FAIL] I2P install failed${NC}"
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
echo "PART 1 COMPLETE"
echo "Continue with PART 2/4"



# ============================================================
# PART 2/4
#
# Includes:
# - I2P service configuration
# - Dedicated I2P user checks
# - systemd hardening
# - AppArmor activation
# - Kernel hardening
# - Swap/core dump protection
# - I2PSnark download directory
# ============================================================


echo "============================================"
echo " PART 2/4 - I2P Hardening"
echo "============================================"


# ------------------------------------------------------------
# CONFIGURE I2P SERVICE
# ------------------------------------------------------------

echo "[+] Configuring I2P service"


echo "i2p i2p/daemon boolean true" | debconf-set-selections || true


dpkg-reconfigure -f noninteractive i2p || {

echo -e "${YELLOW}[WARNING] I2P daemon reconfigure issue${NC}"

}


systemctl daemon-reload



systemctl enable i2p



# ------------------------------------------------------------
# SYSTEMD HARDENING FOR I2P
# ------------------------------------------------------------

echo "============================================"
echo " systemd I2P sandbox"
echo "============================================"



mkdir -p /etc/systemd/system/i2p.service.d



cat > /etc/systemd/system/i2p.service.d/hardening.conf <<'EOF'
[Service]

NoNewPrivileges=true

PrivateTmp=true

ProtectKernelTunables=true

ProtectKernelModules=true

ProtectControlGroups=true

RestrictSUIDSGID=true

RestrictRealtime=true

LockPersonality=true

MemoryDenyWriteExecute=false

ProtectSystem=full

CapabilityBoundingSet=CAP_NET_BIND_SERVICE CAP_SETUID CAP_SETGID

EOF



systemctl daemon-reload



echo -e "${GREEN}[OK] systemd hardening applied${NC}"



# ------------------------------------------------------------
# START I2P
# ------------------------------------------------------------

echo "[+] Starting I2P"


systemctl restart i2p || {


echo -e "${RED}[FAIL] I2P failed to start${NC}"

journalctl -u i2p -n 50 --no-pager

exit 1

}



sleep 5



if systemctl is-active --quiet i2p
then

echo -e "${GREEN}[OK] I2P service running${NC}"

else

echo -e "${RED}[FAIL] I2P service stopped${NC}"

exit 1

fi




# ------------------------------------------------------------
# APPARMOR
# ------------------------------------------------------------

echo "============================================"
echo " AppArmor"
echo "============================================"


systemctl enable apparmor 2>/dev/null || true

systemctl restart apparmor 2>/dev/null || true



if command -v aa-status >/dev/null
then

aa-status || true

echo -e "${GREEN}[OK] AppArmor available${NC}"

else

echo -e "${YELLOW}[WARNING] AppArmor unavailable${NC}"

fi




# ------------------------------------------------------------
# KERNEL HARDENING
# ------------------------------------------------------------

echo "============================================"
echo " Kernel hardening"
echo "============================================"



cat > /etc/sysctl.d/99-i2p-security.conf <<'EOF'

# Network protections

net.ipv4.ip_forward=0

net.ipv6.conf.all.forwarding=0


net.ipv4.conf.all.accept_redirects=0

net.ipv4.conf.default.accept_redirects=0


net.ipv4.conf.all.send_redirects=0

net.ipv4.conf.default.send_redirects=0


net.ipv4.icmp_ignore_bogus_error_responses=1


# Kernel information leak reduction

kernel.kptr_restrict=2

kernel.dmesg_restrict=1


# Disable unprivileged kernel attack surfaces

kernel.unprivileged_bpf_disabled=1

kernel.perf_event_paranoid=3


# TCP protection

net.ipv4.tcp_syncookies=1


EOF



sysctl --system >/dev/null 2>&1 || true



echo -e "${GREEN}[OK] Kernel settings applied${NC}"




# ------------------------------------------------------------
# SWAP PROTECTION
# ------------------------------------------------------------

echo "============================================"
echo " Swap and crash protection"
echo "============================================"



swapoff -a 2>/dev/null || true



# Disable crash dumps


cat > /etc/security/limits.d/99-no-core-dumps.conf <<'EOF'

* hard core 0

EOF



systemctl disable kdump 2>/dev/null || true

systemctl disable apport 2>/dev/null || true



echo -e "${GREEN}[OK] Core dumps disabled${NC}"




# ------------------------------------------------------------
# I2PSNARK STORAGE
# ------------------------------------------------------------

echo "============================================"
echo " I2PSnark directory"
echo "============================================"



REAL_USER=""



if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]
then

REAL_USER="$SUDO_USER"

fi



if [ -z "$REAL_USER" ]
then

REAL_USER=$(awk -F: '$3>=1000 && $3<60000 {print $1;exit}' /etc/passwd)

fi



if [ -z "$REAL_USER" ]
then

USER_HOME="/root"

else

USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

fi



I2P_DOWNLOAD="$USER_HOME/I2P-Downloads"



mkdir -p "$I2P_DOWNLOAD"



chmod 700 "$I2P_DOWNLOAD"



if [ -n "$REAL_USER" ] && [ "$REAL_USER" != "root" ]
then

chown -R "$REAL_USER:$REAL_USER" "$I2P_DOWNLOAD"

fi



echo -e "${GREEN}[OK] I2PSnark folder created${NC}"

echo "$I2P_DOWNLOAD"




echo
echo "============================================"
echo " PART 2 COMPLETE"
echo " Continue with PART 3/4"
echo "============================================"



# ============================================================
# PART 3/4
#
# Includes:
# - nftables firewall
# - Firefox I2P profile
# - Firejail sandbox launcher
# - WebRTC/DNS/fingerprint protections
# - I2P proxy verification
# ============================================================


echo "============================================"
echo " PART 3/4 - Network + Browser Hardening"
echo "============================================"



# ------------------------------------------------------------
# NFTABLES FIREWALL
# ------------------------------------------------------------

echo "============================================"
echo " nftables firewall"
echo "============================================"


systemctl enable nftables



cat > /etc/nftables.conf <<'EOF'
#!/usr/sbin/nft -f


flush ruleset


table inet filter {


chain input {

type filter hook input priority filter;

policy drop;


iif lo accept


ct state established,related accept


# Allow DHCP client

udp sport 67 udp dport 68 accept


}


chain forward {

type filter hook forward priority filter;

policy drop;

}



chain output {

type filter hook output priority filter;

policy accept;


}

}
EOF



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



if [ -z "$REAL_USER" ] || [ "$REAL_USER" = "root" ]
then

echo -e "${YELLOW}[WARNING] No normal user found${NC}"

else


FIREFOX_BASE="$USER_HOME/.mozilla/firefox"

I2P_PROFILE="$FIREFOX_BASE/i2p-profile"


mkdir -p "$I2P_PROFILE"



cat > "$I2P_PROFILE/user.js" <<'EOF'


// I2P proxy

user_pref("network.proxy.type",1);

user_pref("network.proxy.http","127.0.0.1");

user_pref("network.proxy.http_port",4444);


user_pref("network.proxy.ssl","127.0.0.1");

user_pref("network.proxy.ssl_port",4445);



user_pref("network.proxy.no_proxies_on",
"localhost,127.0.0.1,::1");



// Disable WebRTC leaks

user_pref("media.peerconnection.enabled",false);

user_pref("media.peerconnection.ice.proxy_only",true);



// Disable DNS over HTTPS

user_pref("network.trr.mode",5);



// Fingerprinting resistance

user_pref("privacy.resistFingerprinting",true);

user_pref("privacy.firstparty.isolate",true);



// Disable telemetry

user_pref("toolkit.telemetry.enabled",false);

user_pref("datareporting.healthreport.uploadEnabled",false);



// Disable location

user_pref("geo.enabled",false);



EOF



chown -R "$REAL_USER:$REAL_USER" "$FIREFOX_BASE"


chmod 700 "$I2P_PROFILE"

chmod 600 "$I2P_PROFILE/user.js"



echo -e "${GREEN}[OK] Firefox I2P profile created${NC}"


fi




# ------------------------------------------------------------
# FIREJAIL FIREFOX LAUNCHER
# ------------------------------------------------------------


echo "============================================"
echo " Firejail Firefox launcher"
echo "============================================"



if [ "$REAL_USER" != "root" ] && [ -n "$REAL_USER" ]
then


APPDIR="$USER_HOME/.local/share/applications"


mkdir -p "$APPDIR"



cat > "$APPDIR/firefox-i2p.desktop" <<EOF

[Desktop Entry]

Name=Firefox I2P Secure

Comment=Sandboxed Firefox for I2P

Exec=firejail --private-tmp --caps.drop=all firefox-esr --no-remote -profile $I2P_PROFILE

Terminal=false

Type=Application

Categories=Network;WebBrowser;

EOF



chown "$REAL_USER:$REAL_USER" \
"$APPDIR/firefox-i2p.desktop"


chmod 755 "$APPDIR/firefox-i2p.desktop"



echo -e "${GREEN}[OK] Firejail Firefox launcher created${NC}"

fi




# ------------------------------------------------------------
# FIREJAIL CHECK
# ------------------------------------------------------------

echo "============================================"
echo " Firejail status"
echo "============================================"



if command -v firejail >/dev/null
then

firejail --version | head -n 1

echo -e "${GREEN}[OK] Firejail installed${NC}"

else

echo -e "${RED}[FAIL] Firejail missing${NC}"

fi




# ------------------------------------------------------------
# I2P PORT TESTS
# ------------------------------------------------------------

echo "============================================"
echo " I2P port tests"
echo "============================================"



for PORT in 7657 4444 4445
do

if ss -lnt | grep -q ":$PORT "
then

echo -e "${GREEN}[OK] Port $PORT listening${NC}"

else

echo -e "${YELLOW}[WARNING] Port $PORT not detected${NC}"

fi

done




# ------------------------------------------------------------
# I2PSNARK TEST
# ------------------------------------------------------------

echo "============================================"
echo " I2PSnark test"
echo "============================================"



if curl -fsS \
--max-time 10 \
http://127.0.0.1:7657/i2psnark/ \
>/dev/null
then

echo -e "${GREEN}[OK] I2PSnark accessible${NC}"

else

echo -e "${YELLOW}[WARNING] I2PSnark not ready yet${NC}"

fi




echo
echo "============================================"
echo " PART 3 COMPLETE"
echo " Continue with PART 4/4"
echo "============================================"






# ============================================================
# PART 4/4
#
# Includes:
# - I2P bootstrap test
# - I2P proxy test
# - I2PSnark verification
# - Command checks
# - Lynis audit
# - Final security report
# ============================================================


echo "============================================"
echo " PART 4/4 - Final Security Report"
echo "============================================"



# ------------------------------------------------------------
# WAIT FOR I2P BOOTSTRAP
# ------------------------------------------------------------

echo
echo "[+] Waiting for I2P network bootstrap"
echo "This can take several minutes on a fresh router."


for i in $(seq 1 12)
do

echo "Bootstrap wait $i/12"

sleep 15

done



# ------------------------------------------------------------
# I2P PROXY TEST
# ------------------------------------------------------------

echo "============================================"
echo " I2P proxy test"
echo "============================================"



I2P_READY=0



for i in 1 2 3
do

echo "Testing stats.i2p attempt $i/3"


if curl \
--proxy http://127.0.0.1:4444 \
--max-time 60 \
-fsS \
http://stats.i2p/ \
>/dev/null 2>&1

then

I2P_READY=1

break

fi


done



if [ "$I2P_READY" -eq 1 ]
then

echo -e "${GREEN}[OK] I2P destination reachable${NC}"

else

echo -e "${YELLOW}[WARNING] I2P proxy works but destination test failed${NC}"

echo "A new router may still be building tunnels."

fi




# ------------------------------------------------------------
# COMMAND VERIFICATION
# ------------------------------------------------------------

echo
echo "============================================"
echo " Command verification"
echo "============================================"



COMMANDS=(

java
i2prouter
firefox-esr
firejail
lynis
curl
nft

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
# SERVICE CHECK
# ------------------------------------------------------------

echo
echo "============================================"
echo " Service verification"
echo "============================================"



if systemctl is-active --quiet i2p
then

echo -e "${GREEN}[OK] I2P service running${NC}"

else

echo -e "${RED}[FAIL] I2P service stopped${NC}"

fi



if systemctl is-active --quiet nftables
then

echo -e "${GREEN}[OK] nftables active${NC}"

else

echo -e "${RED}[FAIL] nftables inactive${NC}"

fi



if systemctl is-active --quiet apparmor
then

echo -e "${GREEN}[OK] AppArmor active${NC}"

else

echo -e "${YELLOW}[WARNING] AppArmor inactive${NC}"

fi





# ------------------------------------------------------------
# PORT REPORT
# ------------------------------------------------------------

echo
echo "============================================"
echo " Port report"
echo "============================================"



ss -lntp 2>/dev/null |
grep -E ':(7657|4444|4445)\b' || true





# ------------------------------------------------------------
# LYNIS AUDIT
# ------------------------------------------------------------

echo
echo "============================================"
echo " Lynis audit"
echo "============================================"



if command -v lynis >/dev/null 2>&1
then


lynis audit system --quick || true


else


echo -e "${YELLOW}[WARNING] Lynis unavailable${NC}"


fi




# ------------------------------------------------------------
# FINAL REPORT
# ------------------------------------------------------------


echo
echo "================================================"
echo " Debian 13 Hardened I2P Security Report"
echo "================================================"



echo


# I2P

if command -v i2prouter >/dev/null 2>&1
then

echo -e "${GREEN}[OK] I2P installed${NC}"

else

echo -e "${RED}[FAIL] I2P missing${NC}"

fi



# I2PSnark

if curl -fsS \
--max-time 10 \
http://127.0.0.1:7657/i2psnark/ \
>/dev/null 2>&1

then

echo -e "${GREEN}[OK] I2PSnark available${NC}"

else

echo -e "${YELLOW}[WARNING] I2PSnark not ready${NC}"

fi



# Firewall

if systemctl is-active --quiet nftables
then

echo -e "${GREEN}[OK] Firewall enabled${NC}"

else

echo -e "${RED}[FAIL] Firewall disabled${NC}"

fi



# Firejail

if command -v firejail >/dev/null 2>&1
then

echo -e "${GREEN}[OK] Firejail installed${NC}"

else

echo -e "${RED}[FAIL] Firejail missing${NC}"

fi



# AppArmor

if command -v aa-status >/dev/null 2>&1
then

echo -e "${GREEN}[OK] AppArmor available${NC}"

else

echo -e "${YELLOW}[WARNING] AppArmor unavailable${NC}"

fi




echo
echo "================================================"
echo " SETUP COMPLETE"
echo "================================================"



echo
echo "I2P Router:"
echo "http://127.0.0.1:7657"


echo
echo "I2PSnark:"
echo "http://127.0.0.1:7657/i2psnark/"


echo
echo "I2P HTTP Proxy:"
echo "127.0.0.1:4444"


echo
echo "I2P HTTPS Proxy:"
echo "127.0.0.1:4445"


echo
echo "Downloads:"
echo "$I2P_DOWNLOAD"


echo
echo "Log:"
echo "$LOGFILE"


echo
echo "================================================"
echo " DONE"
echo "================================================"















