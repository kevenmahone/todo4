#!/bin/bash

# ============================================================
# Secure Debian 13 Trixie + Java I2P + I2PSnark
#
# Includes:
# - Debian 13 detection
# - Logging
# - Package installation
# - Official I2P Debian repository
# - I2P signing-key fingerprint verification
# - Java installation
# - I2P installation
# - I2P service configuration
# - I2PSnark verification
# - AppArmor
# - Conservative kernel hardening
# - Firefox ESR
# - Dedicated Firefox I2P profile
# - Firefox I2P application-menu launcher
# - HTTP/HTTPS proxy: 127.0.0.1:4444
# - Firejail
# - Lynis audit
#
# UFW intentionally NOT installed.
# ============================================================

set -u
set -o pipefail

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
NC="\033[0m"

LOGFILE="/tmp/debian-live-i2p-setup.log"

exec > >(tee -a "$LOGFILE") 2>&1

echo "============================================"
echo " Debian 13 I2P Setup"
echo " $(date)"
echo "============================================"

# ------------------------------------------------------------
# ROOT CHECK
# ------------------------------------------------------------

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR] This script must be run as root.${NC}"
    echo
    echo "Run:"
    echo "sudo bash secure_debian_live_i2p_verified.sh"
    exit 1
fi

echo -e "${GREEN}[OK] Running as root${NC}"

# ------------------------------------------------------------
# DEBIAN CHECK
# ------------------------------------------------------------

if [ ! -f /etc/os-release ]; then
    echo -e "${RED}[ERROR] /etc/os-release not found.${NC}"
    exit 1
fi

# shellcheck disable=SC1091
. /etc/os-release

echo "Operating system: ${PRETTY_NAME:-unknown}"
echo "Codename: ${VERSION_CODENAME:-unknown}"

if [ "${ID:-}" != "debian" ]; then
    echo -e "${RED}[ERROR] This script requires Debian.${NC}"
    exit 1
fi

if [ "${VERSION_CODENAME:-}" != "trixie" ]; then
    echo -e "${RED}[ERROR] This script requires Debian 13 Trixie.${NC}"
    echo "Detected: ${VERSION_CODENAME:-unknown}"
    exit 1
fi

echo -e "${GREEN}[OK] Debian 13 Trixie detected${NC}"

# ------------------------------------------------------------
# ARCHITECTURE
# ------------------------------------------------------------

ARCH="$(dpkg --print-architecture)"

echo "Architecture: $ARCH"

case "$ARCH" in
    amd64|arm64|armhf|i386|ppc64el|s390x)
        echo -e "${GREEN}[OK] Supported architecture${NC}"
        ;;
    *)
        echo -e "${YELLOW}[WARNING] Architecture $ARCH may not be supported.${NC}"
        ;;
esac

# ------------------------------------------------------------
# INTERNET CHECK
# ------------------------------------------------------------

echo "============================================"
echo " Internet Check"
echo "============================================"

if ping -c 1 -W 3 deb.debian.org >/dev/null 2>&1; then
    echo -e "${GREEN}[OK] Internet reachable${NC}"
else
    echo -e "${YELLOW}[WARNING] ICMP ping failed.${NC}"
    echo "APT may still work if ICMP is blocked."
fi

# ------------------------------------------------------------
# APT UPDATE
# ------------------------------------------------------------

echo "============================================"
echo " Updating Debian package database"
echo "============================================"

if ! apt-get update; then
    echo -e "${RED}[ERROR] apt-get update failed.${NC}"
    exit 1
fi

# ------------------------------------------------------------
# DEPENDENCIES
# ------------------------------------------------------------

echo "============================================"
echo " Installing dependencies"
echo "============================================"

DEPS=(
    curl
    wget
    gnupg
    ca-certificates
    apt-transport-https
    lsb-release
    apparmor
    apparmor-utils
    firejail
    lynis
    procps
    firefox-esr
)

if ! apt-get install -y "${DEPS[@]}"; then
    echo -e "${RED}[ERROR] Dependency installation failed.${NC}"
    exit 1
fi

echo -e "${GREEN}[OK] Dependencies installed${NC}"

# ------------------------------------------------------------
# JAVA
# ------------------------------------------------------------

echo "============================================"
echo " Java"
echo "============================================"

if command -v java >/dev/null 2>&1; then
    echo -e "${GREEN}[OK] Java already installed${NC}"
else
    echo "[+] Installing default JRE"

    if ! apt-get install -y default-jre; then
        echo -e "${RED}[ERROR] Java installation failed.${NC}"
        exit 1
    fi
fi

echo
echo "Java version:"
java -version

# ------------------------------------------------------------
# I2P REPOSITORY
# ------------------------------------------------------------

echo "============================================"
echo " I2P Official Repository"
echo "============================================"

I2P_KEYRING="/usr/share/keyrings/i2p-archive-keyring.gpg"
I2P_SOURCE="/etc/apt/sources.list.d/i2p.list"
I2P_TEMP_KEY="/tmp/i2p-archive-keyring.gpg"

EXPECTED_FINGERPRINT="7840E7610F28B904753549D767ECE5605BCF1346"

echo "[+] Removing old I2P repository configuration"

rm -f "$I2P_SOURCE"
rm -f "$I2P_KEYRING"
rm -f "$I2P_TEMP_KEY"

# ------------------------------------------------------------
# DOWNLOAD I2P KEY
# ------------------------------------------------------------

echo "[+] Downloading official I2P repository signing key"

if ! curl -fsSL \
    "https://i2p.net/i2p-archive-keyring.gpg" \
    -o "$I2P_TEMP_KEY"; then

    echo -e "${RED}[ERROR] Failed to download I2P signing key.${NC}"
    exit 1
fi

if [ ! -s "$I2P_TEMP_KEY" ]; then
    echo -e "${RED}[ERROR] Downloaded I2P key is empty.${NC}"
    exit 1
fi

echo -e "${GREEN}[OK] I2P signing key downloaded${NC}"

# ------------------------------------------------------------
# VERIFY FINGERPRINT
# ------------------------------------------------------------

echo "============================================"
echo " Verifying I2P signing key"
echo "============================================"

FINGERPRINT="$(
    gpg \
        --batch \
        --quiet \
        --keyid-format long \
        --show-keys \
        --with-colons \
        "$I2P_TEMP_KEY" 2>/dev/null |
    awk -F: '$1 == "fpr" {print $10; exit}'
)"

if [ -z "$FINGERPRINT" ]; then
    echo -e "${RED}[ERROR] Could not read I2P signing-key fingerprint.${NC}"
    exit 1
fi

echo "Detected fingerprint:"
echo "$FINGERPRINT"

echo
echo "Expected fingerprint:"
echo "$EXPECTED_FINGERPRINT"

if [ "$FINGERPRINT" != "$EXPECTED_FINGERPRINT" ]; then
    echo
    echo -e "${RED}[ERROR] I2P signing-key fingerprint DOES NOT MATCH.${NC}"
    echo
    echo "Refusing to continue."
    exit 1
fi

echo -e "${GREEN}[OK] I2P signing-key fingerprint verified${NC}"

# ------------------------------------------------------------
# INSTALL KEY
# ------------------------------------------------------------

install -m 0644 "$I2P_TEMP_KEY" "$I2P_KEYRING"
rm -f "$I2P_TEMP_KEY"

echo -e "${GREEN}[OK] I2P keyring installed${NC}"

# ------------------------------------------------------------
# I2P REPOSITORY
# ------------------------------------------------------------

cat > "$I2P_SOURCE" <<EOF
deb [signed-by=$I2P_KEYRING] https://deb.i2p.net/ trixie main
EOF

chmod 0644 "$I2P_SOURCE"

echo
echo "I2P repository:"
cat "$I2P_SOURCE"

# ------------------------------------------------------------
# APT UPDATE WITH I2P
# ------------------------------------------------------------

echo "============================================"
echo " Updating package database with I2P"
echo "============================================"

if ! apt-get update; then
    echo -e "${RED}[ERROR] apt-get update failed after adding I2P repository.${NC}"
    exit 1
fi

# ------------------------------------------------------------
# INSTALL I2P
# ------------------------------------------------------------

echo "============================================"
echo " Installing I2P"
echo "============================================"

if ! apt-get install -y i2p i2p-keyring; then
    echo -e "${RED}[ERROR] I2P installation failed.${NC}"
    exit 1
fi

echo -e "${GREEN}[OK] I2P installed${NC}"

# ------------------------------------------------------------
# VERIFY I2P
# ------------------------------------------------------------

echo "============================================"
echo " Verifying I2P installation"
echo "============================================"

if command -v i2prouter >/dev/null 2>&1; then
    echo -e "${GREEN}[OK] i2prouter found${NC}"
    i2prouter version 2>/dev/null || true
else
    echo -e "${RED}[ERROR] i2prouter command not found.${NC}"
    dpkg -l | grep -i '^ii.*i2p' || true
    exit 1
fi

# ------------------------------------------------------------
# DETECT NORMAL USER
# ------------------------------------------------------------

echo "============================================"
echo " Detecting normal user"
echo "============================================"

REAL_USER=""

if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER:-}" != "root" ]; then
    REAL_USER="$SUDO_USER"
fi

if [ -z "$REAL_USER" ]; then
    REAL_USER="$(
        getent passwd |
        awk -F: '$3 >= 1000 && $3 < 60000 && $1 != "nobody" {
            print $1
            exit
        }'
    )"
fi

if [ -z "$REAL_USER" ]; then
    echo -e "${YELLOW}[WARNING] No normal user detected.${NC}"
    USER_HOME="/root"
else
    USER_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"

    if [ -z "$USER_HOME" ]; then
        USER_HOME="/home/$REAL_USER"
    fi
fi

echo "User: $REAL_USER"
echo "Home: $USER_HOME"

# ------------------------------------------------------------
# DOWNLOAD DIRECTORY
# ------------------------------------------------------------

echo "============================================"
echo " Creating I2P download directory"
echo "============================================"

DOWNLOAD_DIR="$USER_HOME/I2P-Downloads"

mkdir -p "$DOWNLOAD_DIR"

if [ "$REAL_USER" != "root" ] && id "$REAL_USER" >/dev/null 2>&1; then
    chown "$REAL_USER:$REAL_USER" "$DOWNLOAD_DIR"
fi

chmod 700 "$DOWNLOAD_DIR"

echo -e "${GREEN}[OK] $DOWNLOAD_DIR created${NC}"

# ------------------------------------------------------------
# I2P SERVICE
# ------------------------------------------------------------

echo "============================================"
echo " I2P service configuration"
echo "============================================"

if command -v debconf-set-selections >/dev/null 2>&1; then
    echo "i2p i2p/daemon boolean true" | debconf-set-selections
fi

dpkg-reconfigure -f noninteractive i2p >/dev/null 2>&1 || true

systemctl daemon-reload 2>/dev/null || true

if systemctl list-unit-files 2>/dev/null | grep -q '^i2p\.service'; then

    echo -e "${GREEN}[OK] I2P system service exists${NC}"

    systemctl enable i2p 2>/dev/null || true
    systemctl restart i2p 2>/dev/null || systemctl start i2p 2>/dev/null || true

else

    echo -e "${YELLOW}[WARNING] I2P system service was not detected.${NC}"
    echo "I2P can be started manually with:"
    echo "i2prouter start"

fi

# ------------------------------------------------------------
# SERVICE STATUS
# ------------------------------------------------------------

echo "============================================"
echo " I2P service status"
echo "============================================"

if systemctl is-active --quiet i2p 2>/dev/null; then
    echo -e "${GREEN}[OK] I2P system service is running${NC}"
else
    echo -e "${YELLOW}[WARNING] I2P system service is not currently running.${NC}"
    systemctl --no-pager --full status i2p 2>/dev/null | tail -n 20 || true
fi

# ------------------------------------------------------------
# APPARMOR
# ------------------------------------------------------------

echo "============================================"
echo " AppArmor"
echo "============================================"

systemctl enable apparmor 2>/dev/null || true
systemctl start apparmor 2>/dev/null || true

if command -v aa-status >/dev/null 2>&1; then
    if aa-status >/dev/null 2>&1; then
        echo -e "${GREEN}[OK] AppArmor is available${NC}"
    else
        echo -e "${YELLOW}[WARNING] AppArmor status could not be confirmed.${NC}"
    fi
else
    echo -e "${YELLOW}[WARNING] aa-status unavailable.${NC}"
fi

# ------------------------------------------------------------
# KERNEL HARDENING
# ------------------------------------------------------------

echo "============================================"
echo " Conservative kernel hardening"
echo "============================================"

SYSCTL_FILE="/etc/sysctl.d/99-local-security.conf"

cat > "$SYSCTL_FILE" <<'EOF'
# Conservative local security settings.

net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0

net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0

net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

net.ipv4.icmp_ignore_bogus_error_responses = 1

net.ipv4.tcp_syncookies = 1

kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.unprivileged_bpf_disabled = 1
kernel.perf_event_paranoid = 3
EOF

chmod 0644 "$SYSCTL_FILE"

if sysctl --system >/dev/null 2>&1; then
    echo -e "${GREEN}[OK] Kernel settings applied${NC}"
else
    echo -e "${YELLOW}[WARNING] Some kernel settings could not be applied.${NC}"
fi

# ------------------------------------------------------------
# FIREFOX I2P PROFILE
# ------------------------------------------------------------

echo "============================================"
echo " Firefox I2P profile"
echo "============================================"

if [ "$REAL_USER" = "root" ] || [ -z "$REAL_USER" ]; then

    echo -e "${YELLOW}[WARNING] No normal user detected; Firefox profile not created.${NC}"

else

    FIREFOX_DIR="$USER_HOME/.mozilla/firefox"
    PROFILE_DIR="$FIREFOX_DIR/i2p-profile"

    mkdir -p "$FIREFOX_DIR"
    mkdir -p "$PROFILE_DIR"

    cat > "$PROFILE_DIR/user.js" <<'EOF'
// ============================================================
// FIREFOX I2P PROFILE
// ============================================================
//
// HTTP proxy:  127.0.0.1:4444
// HTTPS proxy: 127.0.0.1:4444
//
// This profile is intended for I2P browsing.
// Do not use it as your normal clearnet profile.
// ============================================================

user_pref("network.proxy.type", 1);

user_pref("network.proxy.http", "127.0.0.1");
user_pref("network.proxy.http_port", 4444);

user_pref("network.proxy.ssl", "127.0.0.1");
user_pref("network.proxy.ssl_port", 4444);

user_pref("network.proxy.no_proxies_on",
          "localhost, 127.0.0.1, ::1");

user_pref("network.proxy.socks", "");
user_pref("network.proxy.socks_port", 0);
user_pref("network.proxy.socks_remote_dns", false);

user_pref("network.trr.mode", 5);

user_pref("media.peerconnection.enabled", false);

user_pref("geo.enabled", false);

user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);

user_pref("network.captive-portal-service.enabled", false);
user_pref("network.connectivity-service.enabled", false);
EOF

    chown -R "$REAL_USER:$REAL_USER" "$FIREFOX_DIR"

    chmod 700 "$FIREFOX_DIR"
    chmod 700 "$PROFILE_DIR"
    chmod 600 "$PROFILE_DIR/user.js"

    echo -e "${GREEN}[OK] Firefox I2P profile created${NC}"

    echo
    echo "Profile:"
    echo "$PROFILE_DIR"

    echo
    echo "Proxy:"
    echo "HTTP  -> 127.0.0.1:4444"
    echo "HTTPS -> 127.0.0.1:4444"

    # --------------------------------------------------------
    # FIREFOX APPLICATION LAUNCHER
    # --------------------------------------------------------

    echo "============================================"
    echo " Firefox I2P application"
    echo "============================================"

    APPLICATION_DIR="$USER_HOME/.local/share/applications"

    mkdir -p "$APPLICATION_DIR"

    FIREFOX_LAUNCHER="$APPLICATION_DIR/firefox-i2p.desktop"

    cat > "$FIREFOX_LAUNCHER" <<EOF
[Desktop Entry]
Version=1.0
Name=Firefox I2P
GenericName=I2P Web Browser
Comment=Firefox using the local I2P HTTP proxy
Exec=firefox-esr --no-remote -profile "$PROFILE_DIR"
Icon=firefox-esr
Terminal=false
Type=Application
Categories=Network;WebBrowser;
StartupNotify=true
EOF

    chown "$REAL_USER:$REAL_USER" "$FIREFOX_LAUNCHER"
    chmod 755 "$FIREFOX_LAUNCHER"

    echo -e "${GREEN}[OK] Firefox I2P application created${NC}"
    echo "$FIREFOX_LAUNCHER"

    # --------------------------------------------------------
    # OPTIONAL DESKTOP SHORTCUT
    # --------------------------------------------------------

    DESKTOP_DIR="$USER_HOME/Desktop"

    if [ -d "$DESKTOP_DIR" ]; then

        DESKTOP_LAUNCHER="$DESKTOP_DIR/firefox-i2p.desktop"

        cp "$FIREFOX_LAUNCHER" "$DESKTOP_LAUNCHER"

        chown "$REAL_USER:$REAL_USER" "$DESKTOP_LAUNCHER"
        chmod 755 "$DESKTOP_LAUNCHER"

        echo -e "${GREEN}[OK] Firefox I2P desktop shortcut created${NC}"

    fi

    # --------------------------------------------------------
    # UPDATE DESKTOP DATABASE
    # --------------------------------------------------------

    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$APPLICATION_DIR" >/dev/null 2>&1 || true
    fi

fi

# ------------------------------------------------------------
# FIREJAIL
# ------------------------------------------------------------

echo "============================================"
echo " Firejail"
echo "============================================"

if command -v firejail >/dev/null 2>&1; then
    echo -e "${GREEN}[OK] Firejail installed${NC}"
    firejail --version | head -n 1 || true
else
    echo -e "${YELLOW}[WARNING] Firejail unavailable.${NC}"
fi

# ------------------------------------------------------------
# I2P CONSOLE TEST
# ------------------------------------------------------------

echo "============================================"
echo " Testing I2P console"
echo "============================================"

I2P_READY=0

for attempt in 1 2 3 4 5 6 7 8 9 10; do

    echo "[+] Attempt $attempt/10"

    if curl -fsS --max-time 10 \
        http://127.0.0.1:7657/ >/dev/null 2>&1; then

        I2P_READY=1
        break

    fi

    sleep 5

done

if [ "$I2P_READY" -eq 1 ]; then
    echo -e "${GREEN}[OK] I2P console reachable${NC}"
else
    echo -e "${YELLOW}[WARNING] I2P console is not reachable yet.${NC}"
fi

# ------------------------------------------------------------
# I2PSNARK TEST
# ------------------------------------------------------------

echo "============================================"
echo " Testing I2PSnark"
echo "============================================"

if curl -fsS --max-time 10 \
    http://127.0.0.1:7657/i2psnark/ >/dev/null 2>&1; then

    echo -e "${GREEN}[OK] I2PSnark reachable${NC}"

else

    echo -e "${YELLOW}[WARNING] I2PSnark is not currently reachable.${NC}"

fi

# ------------------------------------------------------------
# COMMAND VERIFICATION
# ------------------------------------------------------------

echo "============================================"
echo " Command verification"
echo "============================================"

check_command()
{
    local CMD="$1"

    if command -v "$CMD" >/dev/null 2>&1; then
        echo -e "${GREEN}[OK] $CMD${NC}"
    else
        echo -e "${RED}[MISSING] $CMD${NC}"
    fi
}

check_command java
check_command i2prouter
check_command firefox-esr
check_command firejail
check_command lynis
check_command curl

# ------------------------------------------------------------
# LYNIS
# ------------------------------------------------------------

echo "============================================"
echo " Lynis security audit"
echo "============================================"

if command -v lynis >/dev/null 2>&1; then
    echo "[+] Running Lynis quick audit"
    lynis audit system --quick || true
else
    echo -e "${YELLOW}[WARNING] Lynis is not installed.${NC}"
fi

# ------------------------------------------------------------
# FINAL REPORT
# ------------------------------------------------------------

echo
echo "================================================"
echo " Debian 13 Java I2P Security Report"
echo "================================================"

echo

if command -v java >/dev/null 2>&1; then
    echo -e "${GREEN}[OK] Java installed${NC}"
else
    echo -e "${RED}[FAIL] Java missing${NC}"
fi

if command -v i2prouter >/dev/null 2>&1; then
    echo -e "${GREEN}[OK] I2P installed${NC}"
else
    echo -e "${RED}[FAIL] I2P missing${NC}"
fi

if [ -f "$I2P_SOURCE" ]; then
    echo -e "${GREEN}[OK] I2P repository configured${NC}"
else
    echo -e "${RED}[FAIL] I2P repository missing${NC}"
fi

if [ -f "$I2P_KEYRING" ]; then
    echo -e "${GREEN}[OK] I2P signing key installed${NC}"
else
    echo -e "${RED}[FAIL] I2P signing key missing${NC}"
fi

if [ -d "$DOWNLOAD_DIR" ]; then
    echo -e "${GREEN}[OK] Download directory ready${NC}"
else
    echo -e "${RED}[FAIL] Download directory missing${NC}"
fi

if command -v firefox-esr >/dev/null 2>&1; then
    echo -e "${GREEN}[OK] Firefox ESR installed${NC}"
else
    echo -e "${RED}[FAIL] Firefox ESR missing${NC}"
fi

if [ "$REAL_USER" != "root" ] &&
   [ -f "$USER_HOME/.local/share/applications/firefox-i2p.desktop" ]; then

    echo -e "${GREEN}[OK] Firefox I2P application created${NC}"

else

    echo -e "${YELLOW}[WARNING] Firefox I2P application unavailable${NC}"

fi

if command -v aa-status >/dev/null 2>&1; then
    echo -e "${GREEN}[OK] AppArmor available${NC}"
else
    echo -e "${YELLOW}[WARNING] AppArmor unavailable${NC}"
fi

if command -v firejail >/dev/null 2>&1; then
    echo -e "${GREEN}[OK] Firejail installed${NC}"
else
    echo -e "${YELLOW}[WARNING] Firejail unavailable${NC}"
fi

echo
echo "================================================"
echo " SETUP FINISHED"
echo "================================================"

echo
echo "I2P Router Console:"
echo "http://127.0.0.1:7657"

echo
echo "I2PSnark:"
echo "http://127.0.0.1:7657/i2psnark/"

echo
echo "I2P HTTP proxy:"
echo "127.0.0.1:4444"

echo
echo "I2P Downloads:"
echo "$DOWNLOAD_DIR"

if [ "$REAL_USER" != "root" ]; then

    echo
    echo "Firefox I2P profile:"
    echo "$USER_HOME/.mozilla/firefox/i2p-profile"

    echo
    echo "Firefox I2P application:"
    echo "$USER_HOME/.local/share/applications/firefox-i2p.desktop"

fi

echo
echo "Log file:"
echo "$LOGFILE"

echo
echo "================================================"
echo " HOW TO USE FIREFOX I2P"
echo "================================================"

echo
echo "1. Make sure the I2P router is running."
echo
echo "2. Open the Debian Applications menu."
echo
echo "3. Search for:"
echo
echo "   Firefox I2P"
echo
echo "4. Launch Firefox I2P."
echo
echo "5. The dedicated Firefox profile automatically uses:"
echo
echo "   HTTP  -> 127.0.0.1:4444"
echo "   HTTPS -> 127.0.0.1:4444"
echo
echo "6. Use this Firefox profile for I2P browsing."
echo
echo "The normal Firefox application remains separate."
echo
echo "IMPORTANT:"
echo "Do not use the Firefox I2P profile for ordinary clearnet browsing."
echo
echo "Debian Live without persistence will lose installed/configured"
echo "changes after reboot unless persistent Live storage is enabled."
echo
echo "====================================
