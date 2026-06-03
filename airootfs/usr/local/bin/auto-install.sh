#!/bin/bash
set -eE -o pipefail

# =====================================================================
#              FAIL-SAFE TELEMETRY AND ERROR TRAPPING ENGINE
# =====================================================================
error_handler() {
    local exit_code=$1
    local line_number=$2
    echo -e "\n=========================================================="
    echo "         🚨 CRITICAL FAULT DETECTED BY ARCHITECT 🚨       "
    echo "=========================================================="
    echo "[FAULT] Command failed with exit code: $exit_code"
    echo "[LOCATION] Failed execution occurred on line: $line_number"
    echo "----------------------------------------------------------"
    echo "Options:"
    echo " [1] Force safe unmount and restart system execution"
    echo " [2] Drop into live emergency recovery shell (Zsh)"
    echo "----------------------------------------------------------"
    read -p "Select recovery path (1-2): " FAULT_CHOICE
    
    if [ "$FAULT_CHOICE" = "2" ]; then
        echo "[INFO] Handing over root bash console. Type 'exit' to return."
        /bin/zsh || true
    fi
    
    umount -R /mnt &>/dev/null || true
    swapoff -a &>/dev/null || true
    sleep 2
    reboot || true
    exit "$exit_code"
}

trap 'error_handler $? $LINENO' ERR

clear
echo "=========================================================="
echo "          EADXM'S AUTOMATED ARCH ARCHITECT v1.15.0        "
echo "=========================================================="
echo ""
echo "Choose your connection architecture:"
echo " [1] ONLINE INSTALL - Download the absolute latest packages."
echo " [2] OFFLINE INSTALL - 100% Air-gapped deployment."
echo ""

while true; do
    read -p "Select mode (1-2): " INSTALL_MODE
    if [[ "$INSTALL_MODE" =~ ^[1-2]$ ]]; then break; else echo "[WARNING] Invalid option."; fi
done

# Global target config definitions
TARGET="/mnt"
ISO_CACHE="/opt/offline_cache"
GRUB_OS_PROBER="true"
EFI_DIR="/boot/efi"
ARCH_ROOT=""

# Base system package matrix 
CORE_PKGS="base linux linux-firmware grub efibootmgr os-prober ntfs-3g networkmanager iwd bluez bluez-utils blueman pipewire pipewire-pulse wireplumber brightnessctl flatpak xorg-server sddm sudo zram-generator earlyoom reflector ttf-dejavu ttf-liberation noto-fonts noto-fonts-emoji curl chaotic-keyring chaotic-mirrorlist parted bc"

# =====================================================================
#              DYNAMIC HARDWARE DRIVE DETECTOR
# =====================================================================
clear
echo "=========================================================="
echo "                TARGET DISK SELECTION MODULE               "
echo "=========================================================="
lsblk -d -o NAME,SIZE,MODEL,TYPE | grep -E "disk|nvme|loop|mmc" || true
echo "----------------------------------------------------------"
echo "Look at the list above. Identify the physical disk you want to install to."

while true; do
    read -p "Type your destination installation disk (e.g., /dev/sda, /dev/nvme0n1): " TARGET_DRIVE
    if [ -b "$TARGET_DRIVE" ]; then break; else echo "[ERROR] Device path does not exist. Try again."; fi
done

umount -R /mnt &>/dev/null || true
if [[ "$TARGET_DRIVE" =~ [0-9]$ ]]; then PART_PREFIX="p"; else PART_PREFIX=""; fi

# =====================================================================
#              NETWORK ENGAGEMENT ENGINE
# =====================================================================
if [ "$INSTALL_MODE" = "1" ]; then
    while true; do
        clear
        if ping -c 1 -W 2 archlinux.org &> /dev/null; then echo "[SUCCESS] Active network connection detected!"; sleep 2; break; fi
        
        WIFI_IFACE=$(iw dev 2>/dev/null | awk '$1=="Interface"{print $2}' | head -n 1) || true
        if [ -z "$WIFI_IFACE" ]; then
            read -p "No Wi-Fi adapter detected! Switch to OFFLINE mode? (y/N): " ESCAPE_CHOICE
            if [[ "$ESCAPE_CHOICE" =~ ^[Yy]$ ]]; then INSTALL_MODE="2"; break; else exit 1; fi
        fi

        iwctl station "$WIFI_IFACE" scan || true; sleep 2
        iwctl station "$WIFI_IFACE" get-networks || true
        read -p "SSID Selection (or type CANCEL): " WIFI_SSID
        
        if [ "$WIFI_SSID" = "CANCEL" ] || [ -z "$WIFI_SSID" ]; then INSTALL_MODE="2"; break; fi
        read -r -s -p "Enter Wi-Fi Password: " WIFI_PASS; echo ""
        
        if [ -z "$WIFI_PASS" ]; then iwctl station "$WIFI_IFACE" connect "$WIFI_SSID" || true
        else iwctl --passphrase "$WIFI_PASS" station "$WIFI_IFACE" connect "$WIFI_SSID" || true; fi
        
        sleep 5
        if ping -c 1 -W 2 archlinux.org &> /dev/null; then break; else read -p "Connection failed. Press Enter to retry..."; fi
    done
fi

# =====================================================================
#              STORAGE PROVISIONING PATHWAY
# =====================================================================
clear
echo "=========================================================="
echo "          STEP 2: STORAGE PROVISIONING PATHWAY            "
echo "=========================================================="
echo " [1] SAFE MULTI-BOOT - Install alongside existing OS (Pick your own partitions)."
echo " [2] REPLACE LINUX   - Wipe old Linux partition."
echo " [3] HARD NUKE       - Wipe the entire drive, clean install."
echo " [4] WINDOWS DUAL-BOOT WIZARD - Auto-shrink Windows C: drive and install Arch."
echo " [5] TARGET NUKE     - Wipe Windows C: drive only."
echo " [6] MANUAL ADVANCED - Launch interactive cfdisk."
echo " [7] DROP TO SHELL   - Exit to Zsh terminal."

while true; do read -p "Enter your choice (1-7): " USER_CHOICE; [[ "$USER_CHOICE" =~ ^[1-7]$ ]] && break; done

case $USER_CHOICE in
    1|2|6)
        if [ "$USER_CHOICE" = "6" ]; then cfdisk "$TARGET_DRIVE"; fi
        
        echo -e "\nHere are your current partitions on $TARGET_DRIVE:"
        lsblk "$TARGET_DRIVE" -o NAME,SIZE,TYPE,FSTYPE
        
        while true; do
            read -p "Enter the partition for Arch ROOT (e.g., /dev/sda3): " ARCH_ROOT
            if [ "$ARCH_ROOT" = "$TARGET_DRIVE" ]; then echo "[ERROR] You selected the entire disk! Choose a partition."; continue; fi
            if [ -b "$ARCH_ROOT" ]; then break; fi
        done

        if [ -d "/sys/firmware/efi" ]; then
            while true; do
                read -p "Enter your EFI partition path (e.g., /dev/sda1): " ARCH_EFI
                if [ "$ARCH_EFI" = "$TARGET_DRIVE" ]; then echo "[ERROR] Choose a partition, not the disk."; continue; fi
                if [ -b "$ARCH_EFI" ]; then break; fi
            done
        fi
        
        if [ "$USER_CHOICE" = "2" ]; then
            read -p "Type 'NUKE' to erase $ARCH_ROOT: " CONFIRM_NUKE
            [ "$CONFIRM_NUKE" != "NUKE" ] && exit 1
        fi

        if [ "$USER_CHOICE" = "6" ]; then
            read -p "Format $ARCH_ROOT to ext4? (y/N): " FORMAT_ROOT
            [[ "$FORMAT_ROOT" =~ ^[Yy]$ ]] && mkfs.ext4 -F "$ARCH_ROOT"
        else
            echo "[INFO] Formatting Root partition to ext4..."
            mkfs.ext4 -F "$ARCH_ROOT"
        fi
        mount "$ARCH_ROOT" "$TARGET"
        
        if [ -d "/sys/firmware/efi" ]; then
            mkdir -p "$TARGET/boot/efi"
            umount "$ARCH_EFI" 2>/dev/null || true
            if [ "$USER_CHOICE" = "6" ]; then
                read -p "Format $ARCH_EFI to FAT32? WARNING: THIS KILLS WINDOWS BOOTLOADER (y/N): " FORMAT_EFI
                [[ "$FORMAT_EFI" =~ ^[Yy]$ ]] && mkfs.vfat -F 32 "$ARCH_EFI"
            fi
            echo "[INFO] Mounting EFI partition..."
            mount -t vfat "$ARCH_EFI" "$TARGET/boot/efi"
        else
            mkdir -p "$TARGET/boot"
        fi
        [ "$USER_CHOICE" = "6" ] && read -p "Enable OS Prober for Dual Boot? (Y/n): " MANUAL_PROBER && [[ "$MANUAL_PROBER" =~ ^[Nn]$ ]] && GRUB_OS_PROBER="true" || GRUB_OS_PROBER="false"
        ;;
        
    3)
        echo "====== HARD NUKE INITIATED ======"
        sleep 3
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
        clear
        echo "====== AUTOMATED WINDOWS DUAL-BOOT WIZARD ======"
        echo "We need a place to install Arch Linux. You can either:"
        echo " [A] Automatically SHRINK your Windows C: Drive to make space."
        echo " [B] Use an ALREADY EMPTY partition you made earlier."
        read -p "Choose A or B: " DUAL_CHOICE
        
        if [[ "$DUAL_CHOICE" =~ ^[Aa]$ ]]; then
            echo -e "\nHere are your current partitions on $TARGET_DRIVE:"
            lsblk "$TARGET_DRIVE" -o NAME,SIZE,TYPE,FSTYPE
            
            while true; do
                read -p "Type your exact Windows C: partition path (e.g., /dev/sda3): " C_DRIVE
                if [ "$C_DRIVE" = "$TARGET_DRIVE" ]; then echo "[ERROR] Do not select the entire disk! Choose the partition."; continue; fi
                if [ -b "$C_DRIVE" ]; then break; fi
            done
            
            read -p "How many Gigabytes (GB) do you want to TAKE from Windows for Arch? (e.g., 50): " ARCH_SIZE_GB
            
            echo "[INFO] Checking and repairing NTFS filesystem on Windows drive..."
            ntfsfix "$C_DRIVE" || true
            
            echo "[INFO] Calculating shrink ratios..."
            C_PART_NUM=$(echo "$C_DRIVE" | grep -o '[0-9]\+$')
            CUR_SIZE_MB=$(parted -s -m "$TARGET_DRIVE" unit MB print | grep "^${C_PART_NUM}:" | cut -d: -f4 | tr -d 'MB' | cut -d. -f1)
            CUR_END_MB=$(parted -s -m "$TARGET_DRIVE" unit MB print | grep "^${C_PART_NUM}:" | cut -d: -f3 | tr -d 'MB' | cut -d. -f1)
            
            SHRINK_MB=$((ARCH_SIZE_GB * 1024))
            NEW_SIZE_MB=$((CUR_SIZE_MB - SHRINK_MB))
            NEW_END_MB=$((CUR_END_MB - SHRINK_MB))
            
            echo "[INFO] Shrinking Windows filesystem... Please wait..."
            ntfsresize -f -s ${NEW_SIZE_MB}M "$C_DRIVE"
            
            echo "[INFO] Shrinking Windows partition boundaries..."
            parted -s -a opt "$TARGET_DRIVE" resizepart "$C_PART_NUM" ${NEW_END_MB}MB
            
            echo "[INFO] Creating new Arch Linux partition in the free space..."
            parted -s -a opt "$TARGET_DRIVE" mkpart primary ext4 ${NEW_END_MB}MB 100%
            partprobe "$TARGET_DRIVE"; udevadm settle; sleep 3
            
            # Identify the newly created partition at the end of the drive
            ARCH_ROOT=$(lsblk -ln -p -o NAME "$TARGET_DRIVE" | grep -E "^${TARGET_DRIVE}${PART_PREFIX}[0-9]+" | sort -V | tail -n 1)
            echo "[SUCCESS] Space created! Arch will be installed to: $ARCH_ROOT"
            
        else
            echo -e "\nHere are your current partitions on $TARGET_DRIVE:"
            lsblk "$TARGET_DRIVE" -o NAME,SIZE,TYPE,FSTYPE
            while true; do
                read -p "Type the EMPTY partition you want to use for Arch (e.g., /dev/sda4): " ARCH_ROOT
                if [ "$ARCH_ROOT" = "$TARGET_DRIVE" ]; then echo "[ERROR] Choose a partition, not a disk."; continue; fi
                if [ -b "$ARCH_ROOT" ]; then break; fi
            done
        fi
        
        echo "[INFO] Formatting Arch Root partition..."
        mkfs.ext4 -F "$ARCH_ROOT"
        mount "$ARCH_ROOT" "$TARGET"
        
        echo "[INFO] Searching for Windows EFI Partition..."
        WIN_EFI=$(lsblk -ln -p -o NAME,FSTYPE "$TARGET_DRIVE" | grep -i vfat | head -n 1 | awk '{print $1}')
        if [ -z "$WIN_EFI" ]; then
            read -p "Could not find it automatically. Enter Windows EFI path (e.g., /dev/sda1): " WIN_EFI
        fi
        
        echo "[INFO] Safely mounting Windows EFI partition (NO FORMATTING)..."
        mkdir -p "$TARGET/boot/efi"
        mount -t vfat "$WIN_EFI" "$TARGET/boot/efi"
        
        GRUB_OS_PROBER="true"
        ;;
        
    5)
        echo "====== TARGET NUKE: ERASE SPECIFIC PARTITION ======"
        echo -e "\nHere are your current partitions on $TARGET_DRIVE:"
        lsblk "$TARGET_DRIVE" -o NAME,SIZE,TYPE,FSTYPE
        
        while true; do
            read -p "Type target Windows partition to WIPE (e.g., /dev/sda3): " C_DRIVE
            if [ "$C_DRIVE" = "$TARGET_DRIVE" ]; then echo "[ERROR] Do not select the whole disk!"; continue; fi
            if [ -b "$C_DRIVE" ]; then break; fi
        done
        
        read -p "Type 'NUKE' to completely erase $C_DRIVE: " CONFIRM_NUKE
        [ "$CONFIRM_NUKE" != "NUKE" ] && exit 1
        
        echo "[INFO] Formatting over Windows..."
        mkfs.ext4 -F "$C_DRIVE"; mount "$C_DRIVE" "$TARGET"
        
        echo "[INFO] Searching for Windows EFI Partition..."
        WIN_EFI=$(lsblk -ln -p -o NAME,FSTYPE "$TARGET_DRIVE" | grep -i vfat | head -n 1 | awk '{print $1}')
        if [ -z "$WIN_EFI" ]; then read -p "Enter Windows EFI path manually: " WIN_EFI; fi
        
        echo "[INFO] Mounting EFI safely..."
        mkdir -p "$TARGET/boot/efi"
        mount -t vfat "$WIN_EFI" "$TARGET/boot/efi"
        GRUB_OS_PROBER="true"
        ;;
    7) exit 0 ;;
esac

# =====================================================================
#              SOFTWARE CONFIGURATION
# =====================================================================
clear
echo "Select your primary web browser:"
echo " [1] LibreWolf (Native - Privacy Hardened)"
echo " [2] Firefox   (Native - Standard)"
echo " [3] Brave     (Native - Chromium Engine)"
echo " [4] None"
read -p "Choice (1-4): " BROWSER_CHOICE
echo ""
read -p "Require LibreOffice suite? (y/N): " OFFICE_CHOICE
read -p "Apply Hyper-Performance Matrix? (ZRAM, Fast I/O) [Y/n]: " PERF_CHOICE

[[ "$OFFICE_CHOICE" =~ ^[Yy]$ ]] && CORE_PKGS="$CORE_PKGS libreoffice-fresh qt5-wayland qt6-wayland"
case $BROWSER_CHOICE in 1) CORE_PKGS="$CORE_PKGS librewolf" ;; 2) CORE_PKGS="$CORE_PKGS firefox" ;; 3) CORE_PKGS="$CORE_PKGS brave-bin" ;; esac

if grep -q "AuthenticAMD" /proc/cpuinfo; then CORE_PKGS="$CORE_PKGS amd-ucode"; elif grep -q "GenuineIntel" /proc/cpuinfo; then CORE_PKGS="$CORE_PKGS intel-ucode"; fi

GPU_COUNT=0
if lspci 2>/dev/null | grep -iq nvidia; then CORE_PKGS="$CORE_PKGS nvidia nvidia-utils"; GPU_COUNT=$((GPU_COUNT + 1)); fi
if lspci 2>/dev/null | grep -iq amd; then CORE_PKGS="$CORE_PKGS xf86-video-amdgpu"; GPU_COUNT=$((GPU_COUNT + 1)); fi
if lspci 2>/dev/null | grep -iq intel; then CORE_PKGS="$CORE_PKGS intel-media-driver"; GPU_COUNT=$((GPU_COUNT + 1)); fi
[ "$GPU_COUNT" -gt 1 ] && CORE_PKGS="$CORE_PKGS switcheroo-control"

echo ""
echo "Select your primary Graphical Desktop Workspace:"
echo " [1] Hyprland   (Hardware-Accelerated Tiling)"
echo " [2] KDE Plasma (Feature-Rich Desktop)"
echo " [3] XFCE       (Lightweight Core)"
read -p "Choice (1-3): " DE_CHOICE

case $DE_CHOICE in
    1) CORE_PKGS="$CORE_PKGS hyprland waybar kitty rofi xdg-desktop-portal-hyprland polkit-kde-agent thunar gvfs" ;;
    2) CORE_PKGS="$CORE_PKGS plasma-desktop plasma-workspace plasma-nm power-profiles-daemon kscreen konsole dolphin ark kate spectacle discover packagekit-qt6 sddm-kcm" ;;
    3) CORE_PKGS="$CORE_PKGS xfce4 xfce4-goodies" ;;
esac

# =====================================================================
#              ACCOUNT CREATION
# =====================================================================
echo ""
read -p "Enter a Hostname for this PC: " system_hostname
system_hostname=$(printf '%s\n' "$system_hostname" | tr -cd 'a-zA-Z0-9-' | tr '[:upper:]' '[:lower:]')
[ -z "$system_hostname" ] && system_hostname="arch-architect"

read -p "Enter your new username: " username
username=$(printf '%s\n' "$username" | tr -cd 'a-z0-9_')
[ -z "$username" ] && username="eadxm_user"

while true; do read -r -s -p "Enter a secure password: " user_password; echo ""; [ -n "$user_password" ] && break; done

# =====================================================================
#              INSTALLATION EXECUTION
# =====================================================================
clear

# 🚨 PREPARE CHAOTIC AUR IN TARGET BEFORE PACSTRAP 🚨
mkdir -p "$TARGET/etc/pacman.d"
echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" >> "$TARGET/etc/pacman.conf"

if [ "$INSTALL_MODE" = "2" ]; then
    echo "[INFO] Deploying OFFLINE using local repository cache..."
    mkdir -p "$TARGET/var/cache/pacman/pkg"
    cp -n "$ISO_CACHE"/* "$TARGET/var/cache/pacman/pkg/" 2>/dev/null || true
    
    mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak || true
    echo "" > /etc/pacman.d/mirrorlist
    sed -i 's/"--refresh"//g' /usr/bin/pacstrap
    sed -i 's/-Sy/-S/g' /usr/bin/pacstrap
    
    pacstrap -c -K "$TARGET" $CORE_PKGS
    mv /etc/pacman.d/mirrorlist.bak /etc/pacman.d/mirrorlist || true
else
    echo "[INFO] Deploying ONLINE..."
    timedatectl set-ntp true
    
    # 🚨 INJECT GLOBAL GEO-MIRROR TO FIX DB SYNC CRASH 🚨
    echo 'Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch' > /etc/pacman.d/mirrorlist
    
    pacman-key --init || true; pacman-key --populate archlinux || true
    
    # Init Chaotic AUR locally so pacstrap can read the keys
    pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com || true
    pacman-key --lsign-key 3056513887B78AEB || true
    pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' --noconfirm || true
    
    trap - ERR 
    DOWNLOAD_SUCCESS=0
    while [ "$DOWNLOAD_SUCCESS" -eq 0 ]; do
        rm -f "$TARGET/var/lib/pacman/db.lck" 2>/dev/null || true
        if pacstrap -K "$TARGET" $CORE_PKGS; then DOWNLOAD_SUCCESS=1
        else read -p "Install failed! Retry? (1=Yes, 2=Reboot): " FAIL_CHOICE; [ "$FAIL_CHOICE" = "2" ] && { umount -R "$TARGET"; reboot; }; fi
    done
    trap 'error_handler $? $LINENO' ERR 
fi

echo "[INFO] Generating File System Table..."
genfstab -U "$TARGET" >> "$TARGET/etc/fstab"

# =====================================================================
#              CHROOT PROVISIONING 
# =====================================================================
echo "[INFO] Configuring System Internals..."
arch-chroot "$TARGET" useradd -m -G wheel -s /bin/bash "$username"
printf '%s:%s\n' "$username" "$user_password" | arch-chroot "$TARGET" chpasswd
printf '%s:%s\n' "root" "$user_password" | arch-chroot "$TARGET" chpasswd
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

arch-chroot "$TARGET" systemctl enable sddm.service NetworkManager.service iwd.service bluetooth.service systemd-timesyncd.service
arch-chroot "$TARGET" systemctl mask systemd-time-wait-sync.service

[[ "$CORE_PKGS" == *"switcheroo-control"* ]] && arch-chroot "$TARGET" systemctl enable switcheroo-control.service || true

mkdir -p "$TARGET/etc/bluetooth"
echo -e "[Policy]\nAutoEnable=true" > "$TARGET/etc/bluetooth/main.conf"

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
    printf 'ParallelDownloads = 10\nColor\nILoveCandy\n' >> "$TARGET/etc/pacman.conf"
    echo -e "[zram0]\nzram-size = ram / 2\ncompression-algorithm = zstd" > "$TARGET/etc/systemd/zram-generator.conf"
    if [ "$(lsblk -nd -o ROTA "$TARGET_DRIVE" | head -n 1)" = "0" ]; then arch-chroot "$TARGET" systemctl enable fstrim.timer || true; fi
fi

echo "[INFO] Installing Bootloader (GRUB)..."
echo "GRUB_DISABLE_OS_PROBER=$GRUB_OS_PROBER" >> "$TARGET/etc/default/grub"
if [ -d "/sys/firmware/efi" ]; then
    arch-chroot "$TARGET" grub-install --target=x86_64-efi --efi-directory="$EFI_DIR" --bootloader-id=ArchLinux --recheck
else
    arch-chroot "$TARGET" grub-install --target=i386-pc "$TARGET_DRIVE" --recheck
fi
arch-chroot "$TARGET" grub-mkconfig -o /boot/grub/grub.cfg

echo "=========================================================="
echo "   EADXM'S ARCH COMPILED! REBOOTING IN 5 SECONDS...       "
echo "=========================================================="
sleep 5
trap - ERR
reboot || true
