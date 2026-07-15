#!/bin/bash
set -eE -o pipefail

# =====================================================================
#              FAIL-SAFE TELEMETRY AND ERROR TRAPPING ENGINE
# =====================================================================
error_handler() {
    local exit_code=$1
    local line_number=$2
    echo -e "\n=========================================================="
    echo "         🚨 CRITICAL FAULT DETECTED BY KESTREL 🚨         "
    echo "=========================================================="
    echo "[FAULT] Command failed with exit code: $exit_code"
    echo "[LOCATION] Failed execution occurred on line: $line_number"
    
    if [ "$NON_INTERACTIVE" = "1" ]; then
        echo "[INFO] GUI Mode active. Aborting deployment."
        umount -R /mnt &>/dev/null || true
        swapoff -a &>/dev/null || true
        exit "$exit_code"
    fi

    echo "----------------------------------------------------------"
    echo "Options:"
    echo " [1] Force safe unmount and restart system execution"
    echo " [2] Drop into live emergency recovery shell (Zsh)"
    echo "----------------------------------------------------------"
    read -r -p "Select recovery path (1-2): " FAULT_CHOICE
    
    if [ "$FAULT_CHOICE" = "2" ]; then
        echo "[INFO] Handing over root bash console. Type 'exit' to return."
        /bin/zsh --no-rcs || true
    fi
    
    umount -R /mnt &>/dev/null || true
    swapoff -a &>/dev/null || true
    sleep 2
    reboot || true
    exit "$exit_code"
}

trap 'error_handler $? $LINENO' ERR

# =====================================================================
#              GUI / HEADLESS OVERRIDE MODULE
# =====================================================================
if [ "$NON_INTERACTIVE" = "1" ]; then
    echo "[INFO] Non-Interactive GUI Mode Engaged."
    
    TARGET_DRIVE="${TARGET_DISK}"
    USER_CHOICE="3"
    CONFIRM_NUKE="YES"
    
    system_hostname="kestrel"
    username="kestrel"
    user_password="password"
    root_password="password"
    
    BROWSER_CHOICE="1"
    PERF_CHOICE="Y"
    
    # 🔧 FIX 1: Respect the variables passed by Rust, fallback to 1 if empty
    DE_CHOICE="${DE_CHOICE:-1}" 
    BOOT_CHOICE="${BOOT_CHOICE:-1}" 

    # 🔧 FIX 2: Auto-detect Install Mode to prevent freezing at the prompt
    if [ -d "/opt/offline_cache" ]; then
        INSTALL_MODE="2"
    else
        INSTALL_MODE="1"
    fi
fi

clear
echo "=========================================================="
echo "               KESTREL ARCH DEPLOYMENT ENGINE               "
echo "=========================================================="
echo ""

TARGET="/mnt"
ISO_CACHE="/opt/offline_cache"
GRUB_OS_PROBER="true" 
EFI_DIR="/boot/efi"
ARCH_ROOT=""
DISPLAY_MANAGER="sddm"

CORE_PKGS="base linux-cachyos linux-cachyos-headers linux-firmware scx-scheds switcheroo-control efibootmgr os-prober ntfs-3g networkmanager iwd bluez bluez-utils blueman pipewire pipewire-pulse wireplumber brightnessctl flatpak xorg-server sudo zram-generator earlyoom reflector ttf-dejavu ttf-liberation noto-fonts noto-fonts-emoji curl chaotic-keyring chaotic-mirrorlist parted foot git stow qt5-wayland qt6-wayland"

if [ -z "$INSTALL_MODE" ]; then
    if [ -d "$ISO_CACHE" ]; then
        echo "Choose your connection architecture:"
        echo " [1] ONLINE INSTALL - Download the absolute latest packages."
        echo " [2] OFFLINE INSTALL - 100% Air-gapped deployment."
        echo ""
        while true; do
            read -r -p "Select mode (1-2): " INSTALL_MODE
            if [[ "$INSTALL_MODE" =~ ^[1-2]$ ]]; then break; else echo "[WARNING] Invalid option."; fi
        done
    else
        echo "[INFO] Standard Arch Linux ISO Detected."
        echo "[INFO] Locking deployment to ONLINE mode (No offline cache present)."
        INSTALL_MODE="1"
        sleep 3
    fi
fi

# =====================================================================
#              DYNAMIC HARDWARE DRIVE DETECTOR
# =====================================================================
if [ -z "$TARGET_DRIVE" ]; then
    clear
    echo "=========================================================="
    echo "                 TARGET DISK SELECTION MODULE                "
    echo "=========================================================="
    lsblk -d -o NAME,SIZE,MODEL,TYPE | grep -E "disk|nvme|loop|mmc" || true
    echo "----------------------------------------------------------"

    while true; do
        read -r -p "Type your destination installation disk (e.g., /dev/sda): " TARGET_DRIVE
        if [ -b "$TARGET_DRIVE" ]; then break; else echo "[ERROR] Device path does not exist. Try again."; fi
    done
fi

umount -R /mnt &>/dev/null || true
if [[ "$TARGET_DRIVE" =~ [0-9]$ ]]; then PART_PREFIX="p"; else PART_PREFIX=""; fi

# =====================================================================
#              NETWORK ENGAGEMENT ENGINE
# =====================================================================
if [ "$INSTALL_MODE" = "1" ] && [ "$NON_INTERACTIVE" != "1" ]; then
    while true; do
        clear
        if ping -c 1 -W 2 archlinux.org &> /dev/null; then echo "[SUCCESS] Active network connection detected!"; sleep 2; break; fi
        
        WIFI_IFACE=$(iw dev 2>/dev/null | awk '$1=="Interface"{print $2}' | head -n 1) || true
        if [ -z "$WIFI_IFACE" ]; then
            read -r -p "No Wi-Fi adapter detected! Switch to OFFLINE mode? (y/N): " ESCAPE_CHOICE
            if [[ "$ESCAPE_CHOICE" =~ ^[Yy]$ ]]; then 
                if [ -d "$ISO_CACHE" ]; then INSTALL_MODE="2"; break; else exit 1; fi
            else exit 1; fi
        fi

        iwctl station "$WIFI_IFACE" scan || true; sleep 2
        iwctl station "$WIFI_IFACE" get-networks || true
        read -r -p "SSID Selection (or type CANCEL): " WIFI_SSID
        
        if [ "$WIFI_SSID" = "CANCEL" ] || [ -z "$WIFI_SSID" ]; then 
            if [ -d "$ISO_CACHE" ]; then INSTALL_MODE="2"; break; else exit 1; fi
        fi
        read -r -s -p "Enter Wi-Fi Password: " WIFI_PASS; echo ""
        
        if [ -z "$WIFI_PASS" ]; then iwctl station "$WIFI_IFACE" connect "$WIFI_SSID" || true
        else iwctl --passphrase "$WIFI_PASS" station "$WIFI_IFACE" connect "$WIFI_SSID" || true; fi
        
        sleep 5
        if ping -c 1 -W 2 archlinux.org &> /dev/null; then break; fi
    done
fi

# =====================================================================
#              STORAGE PROVISIONING PATHWAY
# =====================================================================
clear
if [ ! -d "$ISO_CACHE" ]; then pacman -Sy --noconfirm ntfs-3g parted >/dev/null 2>&1 || true; fi

if [ -z "$USER_CHOICE" ]; then
    echo "=========================================================="
    echo "          STEP 2: STORAGE PROVISIONING PATHWAY            "
    echo "=========================================================="
    echo " [1] SAFE MULTI-BOOT - Install alongside existing OS."
    echo " [2] REPLACE LINUX   - Wipe old Linux partition."
    echo " [3] HARD NUKE       - Wipe the entire drive."
    echo " [4] WINDOWS RESIZE  - Shrink Windows C: drive."
    echo " [5] TARGET NUKE     - Wipe Windows C: drive only."
    echo " [6] MANUAL ADVANCED - cfdisk."
    echo " [7] DROP TO SHELL"
    while true; do read -r -p "Enter your choice (1-7): " USER_CHOICE; [[ "$USER_CHOICE" =~ ^[1-7]$ ]] && break; done
fi

echo "STARTING: Formatting partition tables on $TARGET_DRIVE..."

case $USER_CHOICE in
    1|2|6)
        if [ "$USER_CHOICE" = "6" ]; then cfdisk "$TARGET_DRIVE"; fi
        lsblk "$TARGET_DRIVE" -o NAME,SIZE,TYPE,FSTYPE
        while true; do
            read -r -p "Enter partition for Arch ROOT (e.g., /dev/sda3): " ARCH_ROOT
            if [ -b "$ARCH_ROOT" ] && [ "$ARCH_ROOT" != "$TARGET_DRIVE" ]; then break; fi
        done
        if [ -d "/sys/firmware/efi" ]; then
            while true; do
                read -r -p "Enter EFI partition path (e.g., /dev/sda1): " ARCH_EFI
                if [ -b "$ARCH_EFI" ] && [ "$ARCH_EFI" != "$TARGET_DRIVE" ]; then break; fi
            done
        fi
        
        if [ "$USER_CHOICE" = "2" ]; then
            read -r -p "Type 'NUKE' to erase $ARCH_ROOT: " CONFIRM_NUKE
            [[ "${CONFIRM_NUKE^^}" != "NUKE" ]] && exit 1
        fi

        if [ "$USER_CHOICE" = "6" ]; then
            read -r -p "Format $ARCH_ROOT to ext4? (y/N): " FORMAT_ROOT
            [[ "$FORMAT_ROOT" =~ ^[Yy]$ ]] && mkfs.ext4 -F "$ARCH_ROOT"
        else mkfs.ext4 -F "$ARCH_ROOT"; fi
        mount "$ARCH_ROOT" "$TARGET"
        
        if [ -d "/sys/firmware/efi" ]; then
            mkdir -p "$TARGET/boot/efi"
            umount "$ARCH_EFI" 2>/dev/null || true
            if [ "$USER_CHOICE" = "6" ]; then
                read -r -p "Format $ARCH_EFI to FAT32? (y/N): " FORMAT_EFI
                [[ "$FORMAT_EFI" =~ ^[Yy]$ ]] && mkfs.vfat -F 32 "$ARCH_EFI"
            fi
            mount -t vfat "$ARCH_EFI" "$TARGET/boot/efi"
        else mkdir -p "$TARGET/boot"; fi
        
        if [ "$USER_CHOICE" = "1" ]; then GRUB_OS_PROBER="false"; elif [ "$USER_CHOICE" = "6" ]; then
            read -r -p "Enable OS Prober? (Y/n): " MANUAL_PROBER
            if [[ "$MANUAL_PROBER" =~ ^[Nn]$ ]]; then GRUB_OS_PROBER="true"; else GRUB_OS_PROBER="false"; fi
        fi
        ;;
    3)
        echo "====== HARD NUKE: WIPE ENTIRE DRIVE ======"
        if [ -z "$CONFIRM_NUKE" ]; then read -r -p "🚨 DANGER: Type 'YES' to confirm: " CONFIRM_NUKE; fi
        [[ "${CONFIRM_NUKE^^}" != "YES" ]] && exit 1
        sleep 2
        if [ -d "/sys/firmware/efi" ]; then
            sgdisk --zap-all "$TARGET_DRIVE"
            sgdisk -n 1:0:+1G -t 1:ef00 -c 1:"EFI" "$TARGET_DRIVE"
            sgdisk -n 2:0:0   -t 2:8300 -c 2:"ROOT" "$TARGET_DRIVE"
            partprobe "$TARGET_DRIVE"; udevadm settle; sleep 2
            mkfs.vfat -F 32 "${TARGET_DRIVE}${PART_PREFIX}1"
            mkfs.ext4 -F "${TARGET_DRIVE}${PART_PREFIX}2"
            mount "${TARGET_DRIVE}${PART_PREFIX}2" "$TARGET"
            mkdir -p "$TARGET/boot/efi"
            mount -t vfat "${TARGET_DRIVE}${PART_PREFIX}1" "$TARGET/boot/efi"
            ARCH_EFI="${TARGET_DRIVE}${PART_PREFIX}1"
        else
            sgdisk --zap-all "$TARGET_DRIVE" &>/dev/null || true
            echo "label: dos" | sfdisk "$TARGET_DRIVE" &>/dev/null
            echo ", +" | sfdisk "$TARGET_DRIVE" --force &>/dev/null
            partprobe "$TARGET_DRIVE"; udevadm settle; sleep 2
            ARCH_ROOT="${TARGET_DRIVE}${PART_PREFIX}1"
            mkfs.ext4 -F "$ARCH_ROOT"
            mount "$ARCH_ROOT" "$TARGET"
            EFI_DIR="/boot"
        fi
        GRUB_OS_PROBER="true"
        ;;
    4)
        echo "====== AUTOMATED WINDOWS RESIZE & DUAL BOOT ======"
        read -r -p "Proceed with resize? (y/N): " PROCEED_RESIZE
        [[ ! "$PROCEED_RESIZE" =~ ^[Yy]$ ]] && exit 1
        lsblk "$TARGET_DRIVE" -o NAME,SIZE,TYPE,FSTYPE
        while true; do
            read -r -p "Type Windows C: partition (e.g., /dev/sda3): " C_DRIVE
            if [ -b "$C_DRIVE" ] && [ "$C_DRIVE" != "$TARGET_DRIVE" ]; then break; fi
        done
        read -r -p "Space (in GB) to TAKE from Windows: " ARCH_SIZE_GB
        ntfsfix "$C_DRIVE" || true
        C_PART_NUM=$(echo "$C_DRIVE" | grep -o '[0-9]\+$')
        ntfsresize -f -s -${ARCH_SIZE_GB}G "$C_DRIVE"
        parted -s -a opt "$TARGET_DRIVE" resizepart "$C_PART_NUM" -${ARCH_SIZE_GB}G
        parted -s -a opt "$TARGET_DRIVE" mkpart primary ext4 -${ARCH_SIZE_GB}G 100%
        partprobe "$TARGET_DRIVE"; udevadm settle; sleep 3
        ARCH_ROOT=$(lsblk -ln -p -o NAME "$TARGET_DRIVE" | grep -E "^${TARGET_DRIVE}${PART_PREFIX}[0-9]+" | sort -V | tail -n 1)
        mkfs.ext4 -F "$ARCH_ROOT"
        mount "$ARCH_ROOT" "$TARGET"
        if [ -d "/sys/firmware/efi" ]; then
            WIN_EFI=$(lsblk -ln -p -o NAME,FSTYPE "$TARGET_DRIVE" | grep vfat | head -n 1 | awk '{print $1}')
            if [ -z "$WIN_EFI" ]; then read -r -p "Enter Windows EFI path manually: " WIN_EFI; fi
            mkdir -p "$TARGET/boot/efi"
            fsck.fat -a "$WIN_EFI" || true
            mount -t vfat "$WIN_EFI" "$TARGET/boot/efi"
            ARCH_EFI="$WIN_EFI"
        fi
        GRUB_OS_PROBER="false" 
        ;;
    5)
        echo "====== TARGET NUKE: ERASE SPECIFIC PARTITION ======"
        lsblk "$TARGET_DRIVE" -o NAME,SIZE,TYPE,FSTYPE
        while true; do
            read -r -p "Type target Windows partition to WIPE: " C_DRIVE
            if [ -b "$C_DRIVE" ] && [ "$C_DRIVE" != "$TARGET_DRIVE" ]; then break; fi
        done
        read -r -p "Type 'NUKE' to erase $C_DRIVE: " CONFIRM_NUKE
        [[ "${CONFIRM_NUKE^^}" != "NUKE" ]] && exit 1
        mkfs.ext4 -F "$C_DRIVE"; mount "$C_DRIVE" "$TARGET"
        if [ -d "/sys/firmware/efi" ]; then
            WIN_EFI=$(lsblk -ln -p -o NAME,FSTYPE "$TARGET_DRIVE" | grep vfat | head -n 1 | awk '{print $1}')
            if [ -z "$WIN_EFI" ]; then read -r -p "Enter Windows EFI path manually: " WIN_EFI; fi
            mkdir -p "$TARGET/boot/efi"
            fsck.fat -a "$WIN_EFI" || true
            mount -t vfat "$WIN_EFI" "$TARGET/boot/efi"
            ARCH_EFI="$WIN_EFI"
        fi
        GRUB_OS_PROBER="false"
        ;;
    7) /bin/zsh; exit 0 ;;
esac

# =====================================================================
#              ACCOUNT CREATION
# =====================================================================
clear
echo "=========================================================="
echo "              STEP 3: ACCOUNT CREATION                    "
echo "=========================================================="
if [ -z "$system_hostname" ]; then
    read -r -p "Enter Hostname: " system_hostname
    system_hostname=$(printf '%s\n' "$system_hostname" | tr -cd 'a-zA-Z0-9-' | tr '[:upper:]' '[:lower:]')
    [ -z "$system_hostname" ] && system_hostname="kestrel-node"
fi
if [ -z "$username" ]; then
    read -r -p "Enter new username: " username
    username=$(printf '%s\n' "$username" | tr -cd 'a-z0-9_')
    [ -z "$username" ] && username="kestrel_user"
fi
if [ -z "$user_password" ]; then
    while true; do read -r -s -p "Enter password for $username: " user_password; echo ""; [ -n "$user_password" ] && break; done
fi
if [ -z "$root_password" ]; then
    read -r -p "Use same password for 'root'? [Y/n]: " SAME_ROOT
    if [[ "$SAME_ROOT" =~ ^[Nn]$ ]]; then
        while true; do read -r -s -p "Enter root password: " root_password; echo ""; [ -n "$root_password" ] && break; done
    else root_password="$user_password"; fi
fi

# =====================================================================
#              SOFTWARE CONFIGURATION & DE MATRIX
# =====================================================================
clear
if [ -z "$BROWSER_CHOICE" ]; then
    if [ "$INSTALL_MODE" = "1" ]; then
        echo "Select your primary web browser:"
        echo " [1] Zen Browser (Recommended)"
        echo " [2] LibreWolf"
        echo " [3] Firefox"
        echo " [4] Brave"
        read -r -p "Choice (1-4): " BROWSER_CHOICE
    else
        echo "[INFO] Offline Mode: Defaulting to Zen Browser."
        BROWSER_CHOICE="1"
        sleep 3
    fi
fi

case $BROWSER_CHOICE in 
    1) CORE_PKGS="$CORE_PKGS zen-browser-bin" ;;
    2) CORE_PKGS="$CORE_PKGS librewolf" ;; 
    3) CORE_PKGS="$CORE_PKGS firefox" ;; 
    4) CORE_PKGS="$CORE_PKGS brave-bin" ;; 
esac

if [ -z "$PERF_CHOICE" ]; then read -r -p "Apply Hyper-Performance Matrix? (ZRAM, Fast I/O) [Y/n]: " PERF_CHOICE; fi

UCODE_IMG=""
if grep -q "AuthenticAMD" /proc/cpuinfo; then CORE_PKGS="$CORE_PKGS amd-ucode"; UCODE_IMG="amd-ucode.img"; elif grep -q "GenuineIntel" /proc/cpuinfo; then CORE_PKGS="$CORE_PKGS intel-ucode"; UCODE_IMG="intel-ucode.img"; fi

# Universal Hybrid Graphics Detection Mechanism
HAS_NVIDIA=0; HAS_INTEGRATED=0
if lspci | grep -iq nvidia; then CORE_PKGS="$CORE_PKGS nvidia nvidia-utils nvidia-prime"; HAS_NVIDIA=1; fi
if lspci | grep -E -iq "amd|intel"; then HAS_INTEGRATED=1; fi
if lspci | grep -i vga | grep -iq amd; then CORE_PKGS="$CORE_PKGS xf86-video-amdgpu"; fi
if lspci | grep -i vga | grep -iq intel; then CORE_PKGS="$CORE_PKGS intel-media-driver"; fi

if [ -z "$DE_CHOICE" ]; then
    if [ "$INSTALL_MODE" = "2" ]; then
        echo "=== OFFLINE DESKTOP ENVIRONMENT SELECTOR ==="
        echo " [1] Hyprland   - A visually pleasing dynamic tiling Wayland compositor."
        echo " [2] KDE Plasma - A comprehensive, flexible, highly customizable desktop environment."
        echo " [3] XFCE       - Modern, lightweight, stable, traditional drop-down layout."
        while true; do read -r -p "Choice (1-3): " DE_CHOICE; [[ "$DE_CHOICE" =~ ^[1-3]$ ]] && break; done
    else
        echo "=== ONLINE DESKTOP ENVIRONMENT SELECTOR ==="
        echo " [1] Hyprland   - Visually pleasing Wayland compositor using dynamic tiling."
        echo " [2] KDE Plasma - Flexible desktop offering multiple styles of menus and KWin."
        echo " [3] XFCE       - Lightweight and flexible core with traditional desktop flow."
        echo " [4] GNOME      - User-friendly desktop environment with a modern touch layout."
        echo " [5] Sway       - Tiling Wayland compositor; dynamic drop-in i3 upgrade."
        echo " [6] i3-wm      - Popular X11 tiling manager leveraging clean text configurations."
        echo " [7] Cinnamon   - Traditional desktop paradigm balancing advanced internal features."
        echo " [8] Niri       - Scrollable tiling Wayland compositor optimizing fluid layout grid."
        echo " [9] Qtile      - Highly configurable X11/Wayland environment scripted entirely in Python."
        echo " [10] Wayfire   - Wlroots Wayland engine mixing structural performance aesthetics."
        echo " [11] bspwm     - Binary space partitioning X11 architecture tracking strict window layouts."
        echo " [12] Budgie     - Clean and elegant GTK interface prioritizing absolute modern ergonomics."
        echo " [13] Cosmic     - Modern performance Rust workspace constructed for absolute responsiveness."
        echo " [14] LXDE       - Fast, lightweight X11 environment tailored heavily for legacy hardware."
        echo " [15] LXQt       - Blazing fast lightweight environment engineered entirely on the Qt stack."
        echo " [16] Matede     - Classic GNOME 2 fork tracking legacy desktop layouts natively."
        echo " [17] Openbox    - Highly custom X11 window manager featuring extensive internal canvas styling."
        while true; do read -r -p "Choice (1-17): " DE_CHOICE; [[ "$DE_CHOICE" =~ ^[1-9]$|^1[0-7]$ ]] && break; done
    fi
fi

case $DE_CHOICE in
    1) CORE_PKGS="$CORE_PKGS hyprland waybar kitty rofi-wayland xdg-desktop-portal-hyprland polkit-kde-agent thunar gvfs sddm" ;;
    2) CORE_PKGS="$CORE_PKGS plasma-desktop plasma-workspace plasma-nm power-profiles-daemon kscreen konsole dolphin ark kate spectacle discover packagekit-qt6 sddm-kcm sddm" ;;
    3) CORE_PKGS="$CORE_PKGS xfce4 xfce4-terminal xfce4-goodies sddm" ;;
    4) CORE_PKGS="$CORE_PKGS gnome gnome-tweaks gdm"; DISPLAY_MANAGER="gdm" ;;
    5) CORE_PKGS="$CORE_PKGS sway swaybg swaylock swayidle waybar kitty rofi-wayland xdg-desktop-portal-wlr polkit-kde-agent thunar gvfs sddm" ;;
    6) CORE_PKGS="$CORE_PKGS i3-wm i3status i3lock dmenu kitty picom nitrogen polkit-gnome thunar gvfs sddm" ;;
    7) CORE_PKGS="$CORE_PKGS cinnamon nemo-fileroller gnome-terminal sddm" ;;
    8) CORE_PKGS="$CORE_PKGS niri waybar kitty rofi-wayland xdg-desktop-portal-gnome polkit-kde-agent thunar gvfs sddm" ;;
    9) CORE_PKGS="$CORE_PKGS qtile kitty rofi-wayland xdg-desktop-portal-wlr polkit-kde-agent thunar gvfs sddm" ;;
    10) CORE_PKGS="$CORE_PKGS wayfire wayfire-plugins-extra kitty rofi-wayland xdg-desktop-portal-wlr polkit-kde-agent thunar gvfs sddm" ;;
    11) CORE_PKGS="$CORE_PKGS bspwm sxhkd kitty dmenu picom nitrogen polkit-gnome thunar gvfs sddm" ;;
    12) CORE_PKGS="$CORE_PKGS budgie-desktop sddm" ;;
    13) CORE_PKGS="$CORE_PKGS cosmic-session sddm" ;;
    14) CORE_PKGS="$CORE_PKGS lxde-common lxsession openbox sddm" ;;
    15) CORE_PKGS="$CORE_PKGS lxqt lxqt-session sddm" ;;
    16) CORE_PKGS="$CORE_PKGS mate mate-extra sddm" ;;
    17) CORE_PKGS="$CORE_PKGS openbox obconf tint2 kitty dmenu nitrogen sddm" ;;
esac

# =====================================================================
#              BOOT MANAGER CONFIGURATION STAGE
# =====================================================================
clear
if [ -z "$BOOT_CHOICE" ]; then
    echo "=== BOOT MANAGER CONFIGURATION MATRIX ==="
    echo " [1] GRUB          - Flexible multi-boot loader; supports auto BTRFS snapshot lists."
    echo " [2] systemd-boot  - Light minimalist EFI manager tracking kernel slots in loader.conf."
    echo " [3] rEFInd        - Rich graphical shell automatically identifying boot options."
    echo " [4] Limine        - Modern lightning-fast system deployed cleanly via limine.conf."
    while true; do read -r -p "Choice (1-4): " BOOT_CHOICE; [[ "$BOOT_CHOICE" =~ ^[1-4]$ ]] && break; done
fi

# Add explicit runtime target applications per chosen manager
case $BOOT_CHOICE in
    1) CORE_PKGS="$CORE_PKGS grub" ;;
    2) : ;; # systemd-boot is built into systemd core natively
    3) CORE_PKGS="$CORE_PKGS refind" ;;
    4) CORE_PKGS="$CORE_PKGS limine" ;;
esac

# =====================================================================
#              INSTALLATION EXECUTION
# =====================================================================
clear
sed -i 's/^#Color/Color\nILoveCandy/' /etc/pacman.conf 2>/dev/null || true
sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 10/' /etc/pacman.conf 2>/dev/null || true

echo "STARTING: Running pacstrap (Installing base system)..."

if [ "$INSTALL_MODE" = "2" ]; then
    cat << EOF > /tmp/offline-pacman.conf
[options]
Architecture = auto
SigLevel = Optional TrustAll
[kestrel-offline]
SigLevel = Optional TrustAll
Server = file://$ISO_CACHE/
EOF
    mkdir -p "$TARGET/var/cache/pacman/pkg"
    cp -n "$ISO_CACHE"/* "$TARGET/var/cache/pacman/pkg/" 2>/dev/null || true
    pacstrap -C /tmp/offline-pacman.conf -K "$TARGET" --noconfirm $CORE_PKGS
    cp /etc/pacman.conf "$TARGET/etc/pacman.conf"
else
    timedatectl set-ntp true
    if command -v reflector &> /dev/null; then
        reflector --latest 10 --sort rate --save /etc/pacman.d/mirrorlist &>/dev/null || echo 'Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch' > /etc/pacman.d/mirrorlist
    else echo 'Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch' > /etc/pacman.d/mirrorlist; fi
    
    pacman-key --init >/dev/null 2>&1 || true
    pacman-key --populate archlinux >/dev/null 2>&1 || true
    pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com >/dev/null 2>&1
    pacman-key --lsign-key 3056513887B78AEB >/dev/null 2>&1
    pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' --noconfirm >/dev/null 2>&1
    echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" >> /etc/pacman.conf
    
    trap - ERR 
    DOWNLOAD_SUCCESS=0
    while [ "$DOWNLOAD_SUCCESS" -eq 0 ]; do
        rm -f "$TARGET/var/lib/pacman/db.lck" 2>/dev/null || true
        if pacstrap -K "$TARGET" --noconfirm $CORE_PKGS; then DOWNLOAD_SUCCESS=1; else 
            if [ "$NON_INTERACTIVE" = "1" ]; then exit 1; else
                read -r -p "Install failed! Retry? (1=Yes, 2=Reboot): " FAIL_CHOICE; [ "$FAIL_CHOICE" = "2" ] && { umount -R "$TARGET"; reboot; }
            fi
        fi
    done
    trap 'error_handler $? $LINENO' ERR 
fi

mkdir -p "$TARGET/etc/pacman.d"
echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" >> "$TARGET/etc/pacman.conf"
genfstab -U "$TARGET" >> "$TARGET/etc/fstab"

# =====================================================================
#              CHROOT SYSTEM CONFIGURATION & TARGET INITIALIZATION
# =====================================================================
arch-chroot "$TARGET" useradd -m -G wheel -s /bin/bash "$username"
printf '%s:%s\n' "$username" "$user_password" | arch-chroot "$TARGET" chpasswd
printf '%s:%s\n' "root" "$root_password" | arch-chroot "$TARGET" chpasswd
printf '%s\n' "$system_hostname" > "$TARGET/etc/hostname"
echo -e "127.0.0.1 localhost\n::1 localhost\n127.0.1.1 ${system_hostname}.localdomain ${system_hostname}" > "$TARGET/etc/hosts"

mkdir -p "$TARGET/etc/sudoers.d"
echo "%wheel ALL=(ALL:ALL) ALL" > "$TARGET/etc/sudoers.d/wheel"
chmod 440 "$TARGET/etc/sudoers.d/wheel"

echo "en_US.UTF-8 UTF-8" > "$TARGET/etc/locale.gen"
arch-chroot "$TARGET" locale-gen
echo "LANG=en_US.UTF-8" > "$TARGET/etc/locale.conf"

LIVE_KEYMAP=$(localectl status 2>/dev/null | grep "VC Keymap" | awk '{print $3}' || true)
[ -z "$LIVE_KEYMAP" ] && LIVE_KEYMAP="us"
printf 'KEYMAP=%s\n' "$LIVE_KEYMAP" > "$TARGET/etc/vconsole.conf"
arch-chroot "$TARGET" ln -sf /usr/share/zoneinfo/UTC /etc/localtime
arch-chroot "$TARGET" hwclock --systohc

if [ "$INSTALL_MODE" = "1" ]; then
    mkdir -p "$TARGET/var/lib/iwd" "$TARGET/etc/NetworkManager/conf.d"
    cp -r /var/lib/iwd/* "$TARGET/var/lib/iwd/" 2>/dev/null || true
    echo -e "[device]\nwifi.backend=iwd" > "$TARGET/etc/NetworkManager/conf.d/wifi_backend.conf"
fi

# Enable Display Manager, Networking, scx scheduling, and switcheroo-control for hybrid rendering UI
arch-chroot "$TARGET" systemctl enable ${DISPLAY_MANAGER}.service NetworkManager.service iwd.service bluetooth.service systemd-timesyncd.service scx.service switcheroo-control.service || true
arch-chroot "$TARGET" systemctl mask systemd-time-wait-sync.service

mkdir -p "$TARGET/etc/bluetooth"
echo -e "[Policy]\nAutoEnable=true" > "$TARGET/etc/bluetooth/main.conf"

# Native Universal Hybrid Graphics Configuration Hook
if [ "$HAS_NVIDIA" -eq 1 ] && [ "$HAS_INTEGRATED" -eq 1 ]; then
    echo "[INFO] Injecting hardware hybrid graphics modules settings..."
    mkdir -p "$TARGET/etc/modprobe.d"
    echo "options nvidia \"NVreg_DynamicPowerManagement=0x02\"" > "$TARGET/etc/modprobe.d/nvidia.conf"
    
    mkdir -p "$TARGET/etc/udev/rules.d"
    cat << 'EOF' > "$TARGET/etc/udev/rules.d/80-nvidia-pm.rules"
# Enable runtime power management for NVIDIA graphics controller
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", ATTR{power/control}="auto"
# Enable runtime power management for NVIDIA audio controller
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", ATTR{power/control}="auto"
EOF
fi

cat << 'EOF' >> "$TARGET/home/$username/.bashrc"
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias pacman='sudo pacman --color auto'
alias update='sudo pacman -Syu'
PS1='\[\e[1;36m\]\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ '
EOF
arch-chroot "$TARGET" chown -R "$username:$username" "/home/$username"

if [[ "$PERF_CHOICE" =~ ^[Yy]$ || -z "$PERF_CHOICE" ]]; then
    arch-chroot "$TARGET" systemctl enable earlyoom.service || true
    sed -i 's/#MAKEFLAGS="-j2"/MAKEFLAGS="-j$(nproc)"/' "$TARGET/etc/makepkg.conf"
    sed -i 's/^COMPRESSZST=.*/COMPRESSZST=(zstd -c -T0 -)/' "$TARGET/etc/makepkg.conf"
    sed -i 's/^#Color/Color\nILoveCandy/' "$TARGET/etc/pacman.conf" 2>/dev/null || true
    sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 10/' "$TARGET/etc/pacman.conf" 2>/dev/null || true
    echo -e "[zram0]\nzram-size = ram / 2\ncompression-algorithm = zstd" > "$TARGET/etc/systemd/zram-generator.conf"
    if [ "$(lsblk -nd -o ROTA "$TARGET_DRIVE" | head -n 1)" = "0" ]; then arch-chroot "$TARGET" systemctl enable fstrim.timer || true; fi
fi

# =====================================================================
#              CHROOT PROVISIONING: BOOT MANAGERS DEPLOYMENT
# =====================================================================
echo "STARTING: Installing and deploying selected boot loader framework..."
ROOT_UUID=$(blkid -s UUID -o value "$(lsblk -ln -p -o NAME "$TARGET_DRIVE" | grep -E "^${TARGET_DRIVE}${PART_PREFIX}[0-9]+" | sort -V | tail -n 1)")

# Dynamically inject NVIDIA modeset if detected
NVIDIA_CMDLINE=""
if [ "$HAS_NVIDIA" -eq 1 ]; then
    NVIDIA_CMDLINE=" nvidia-drm.modeset=1"
fi

case $BOOT_CHOICE in
    1)
        # GRUB
        echo "GRUB_DISABLE_OS_PROBER=$GRUB_OS_PROBER" >> "$TARGET/etc/default/grub"
        sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"nowatchdog zswap.enabled=0 quiet splash mitigations=off${NVIDIA_CMDLINE}\"/" "$TARGET/etc/default/grub"
        if [ -d "/sys/firmware/efi" ]; then
            arch-chroot "$TARGET" grub-install --target=x86_64-efi --efi-directory="$EFI_DIR" --bootloader-id=KestrelArch --recheck
        else
            arch-chroot "$TARGET" grub-install --target=i386-pc "$TARGET_DRIVE" --recheck
        fi
        arch-chroot "$TARGET" grub-mkconfig -o /boot/grub/grub.cfg
        ;;
    2)
        # systemd-boot
        arch-chroot "$TARGET" bootctl install
        echo -e "default arch.conf\ntimeout 5" > "$TARGET/boot/loader/loader.conf"
        
        {
            echo "title Kestrel Arch"
            echo "linux /vmlinuz-linux-cachyos"
            [ -n "$UCODE_IMG" ] && echo "initrd /${UCODE_IMG}"
            echo "initrd /initramfs-linux-cachyos.img"
            echo "options root=UUID=${ROOT_UUID} rw nowatchdog zswap.enabled=0 quiet splash mitigations=off${NVIDIA_CMDLINE}"
        } > "$TARGET/boot/loader/entries/arch.conf"
        ;;
    3)
        # rEFInd
        arch-chroot "$TARGET" refind-install
        UCODE_STR=""
        [ -n "$UCODE_IMG" ] && UCODE_STR="initrd=${UCODE_IMG} "
        echo "\"Boot using default options\" \"root=UUID=${ROOT_UUID} rw ${UCODE_STR}initrd=initramfs-linux-cachyos.img nowatchdog zswap.enabled=0 quiet splash mitigations=off${NVIDIA_CMDLINE}\"" > "$TARGET/boot/refind_linux.conf"
        ;;
    4)
        # Limine
        mkdir -p "$TARGET/boot/EFI/BOOT"
        cp "$TARGET/usr/share/limine/BOOTX64.EFI" "$TARGET/boot/EFI/BOOT/BOOTX64.EFI"
        UCODE_STR=""
        [ -n "$UCODE_IMG" ] && UCODE_STR="module_path: boot():/${UCODE_IMG}\n    "
        
        cat << EOF > "$TARGET/boot/limine.conf"
timeout: 5
default_entry: 1
:Kestrel Arch
    protocol: linux
    kernel_path: boot():/vmlinuz-linux-cachyos
    ${UCODE_STR}module_path: boot():/initramfs-linux-cachyos.img
    cmdline: root=UUID=${ROOT_UUID} rw nowatchdog zswap.enabled=0 quiet splash mitigations=off${NVIDIA_CMDLINE}
EOF
        if [ ! -d "/sys/firmware/efi" ]; then
            arch-chroot "$TARGET" limine deploy "$TARGET_DRIVE" || true
        fi
        ;;
esac

echo "=========================================================="
echo "   KESTREL ARCH DEPLOYED! REBOOTING IN 5 SECONDS...       "
echo "=========================================================="
sleep 5

if [ "$NON_INTERACTIVE" = "1" ]; then
    trap - ERR; umount -R "$TARGET" 2>/dev/null || true; exit 0
fi

trap - ERR; umount -R "$TARGET" 2>/dev/null || true; reboot || true
