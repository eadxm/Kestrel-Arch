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
    
    echo "[INFO] Safely unmounting storage arrays before exit..."
    umount -R /mnt &>/dev/null || true
    swapoff -a &>/dev/null || true
    echo "[INFO] Rebooting machine..."
    sleep 2
    reboot || true
    exit "$exit_code"
}

trap 'error_handler $? $LINENO' ERR

clear
echo "=========================================================="
echo "          EADXM'S AUTOMATED ARCH ARCHITECT v1.12.0        "
echo "=========================================================="
echo ""
echo "Choose your connection architecture:"
echo " [1] ONLINE INSTALL - Download the absolute latest packages & full browser matrix."
echo " [2] OFFLINE INSTALL - 100% Air-gapped deployment using pre-baked ISO assets."
echo ""

while true; do
    read -p "Select mode (1-2): " INSTALL_MODE
    if [[ "$INSTALL_MODE" =~ ^[1-2]$ ]]; then
        break
    else
        echo "[WARNING] Invalid option. Please select 1 or 2."
    fi
done

# Global target config definitions
TARGET="/mnt"
ISO_CACHE="/var/cache/pacman/pkg"
GRUB_OS_PROBER="true"
EFI_DIR="/boot"
ARCH_ROOT=""
FLATPAK_APP=""

# Base system package matrix 
CORE_PKGS="base linux linux-firmware grub efibootmgr os-prober ntfs-3g networkmanager iwd bluez bluez-utils blueman pipewire pipewire-pulse wireplumber brightnessctl flatpak xorg-server sddm sudo zram-generator earlyoom reflector ttf-dejavu ttf-liberation noto-fonts noto-fonts-emoji systemd-timesyncd curl"

# =====================================================================
#              DYNAMIC HARDWARE DRIVE DETECTOR & PRE-FLIGHT
# =====================================================================
clear
echo "=========================================================="
echo "                TARGET DISK SELECTION MODULE               "
echo "=========================================================="
echo "[INFO] Scanning for available block storage devices..."
echo "----------------------------------------------------------"
lsblk -d -o NAME,SIZE,MODEL,TYPE | grep -E "disk|nvme|loop|mmc" || true
echo "----------------------------------------------------------"

while true; do
    read -p "Type your destination installation disk (e.g., /dev/sda, /dev/nvme0n1, /dev/mmcblk0): " TARGET_DRIVE
    if [ -b "$TARGET_DRIVE" ]; then
        break
    else
        echo "[ERROR] Device path '$TARGET_DRIVE' does not exist or is not a block device. Try again."
    fi
done

echo "[INFO] Clearing environmental block locks..."
umount -R /mnt &>/dev/null || true

# Smart Partition Naming Generator for NVMe/eMMC/SDA drive compliance
if [[ "$TARGET_DRIVE" =~ [0-9]$ ]]; then
    PART_PREFIX="p"
else
    PART_PREFIX=""
fi

# =====================================================================
#              NETWORK ENGAGEMENT ENGINE (ONLINE ONLY)
# =====================================================================
if [ "$INSTALL_MODE" = "1" ]; then
    while true; do
        clear
        echo "=========================================================="
        echo "              WIRELESS CONNECTION MANAGEMENT              "
        echo "=========================================================="
        
        if ping -c 1 -W 2 archlinux.org &> /dev/null; then
            echo "[SUCCESS] Active network connection detected! Skipping Wi-Fi setup."
            sleep 2
            break
        fi

        echo "[INFO] No active connection. Initializing Native Wi-Fi Subsystem (iwd)..."
        
        WIFI_IFACE=$(iw dev 2>/dev/null | awk '$1=="Interface"{print $2}' | head -n 1) || true

        if [ -z "$WIFI_IFACE" ]; then
            echo "[ERROR] No Wi-Fi adapter detected on this motherboard!"
            read -p "Drop down and continue as OFFLINE installation? (y/N): " ESCAPE_CHOICE
            if [[ "$ESCAPE_CHOICE" =~ ^[Yy]$ ]]; then
                INSTALL_MODE="2"
                sleep 2
                break
            else
                exit 1
            fi
        fi

        echo "[INFO] Scanning for networks on $WIFI_IFACE..."
        iwctl station "$WIFI_IFACE" scan || true
        sleep 2
        
        echo "----------------------------------------------------------"
        iwctl station "$WIFI_IFACE" get-networks || true
        echo "----------------------------------------------------------"
        echo "Type the exact name (SSID) of your network to connect."
        echo "Or type 'CANCEL' to drop to offline mode."
        echo "----------------------------------------------------------"
        read -p "SSID Selection: " WIFI_SSID
        
        if [ "$WIFI_SSID" = "CANCEL" ] || [ -z "$WIFI_SSID" ]; then
            echo -e "\n[WARNING] Wi-Fi configuration aborted. Switching to OFFLINE mode."
            INSTALL_MODE="2"
            sleep 2
            break
        fi
        
        read -r -s -p "Enter Wi-Fi Password (leave blank for Open Network): " WIFI_PASS
        echo -e "\n\n[INFO] Authenticating and linking with $WIFI_SSID..."
        
        if [ -z "$WIFI_PASS" ]; then
            iwctl station "$WIFI_IFACE" connect "$WIFI_SSID" || true
        else
            iwctl --passphrase "$WIFI_PASS" station "$WIFI_IFACE" connect "$WIFI_SSID" || true
        fi
        
        echo "[INFO] Waiting 5 seconds for DHCP IP assignment..."
        sleep 5
        
        if ping -c 1 -W 2 archlinux.org &> /dev/null; then
            echo "[SUCCESS] Connected successfully! Internet uplink established."
            sleep 2
            break
        else
            echo -e "\n[ERROR] Connection failed. Incorrect password or poor signal."
            read -p "Press Enter to try again..."
        fi
    done
fi

# =====================================================================
#              DRIVE HARDWARE STORAGE ARCHITECTURE SELECTOR
# =====================================================================
clear
echo "=========================================================="
echo "          STEP 2: STORAGE PROVISIONING PATHWAY            "
echo "=========================================================="
echo ""
echo "Select your installation pathway:"
echo " [1] SAFE MULTI-BOOT - Install alongside Windows/Linux on an existing empty partition."
echo " [2] REPLACE LINUX   - Wipe an old Linux partition, replace with Arch, keep Windows/EFI."
echo " [3] HARD NUKE       - Wipe the entire drive, build an adaptive firmware layout, clean install."
echo " [4] WINDOWS RESIZE  - Auto-shrink Windows C: drive and create Arch Dual-Boot."
echo " [5] TARGET NUKE     - Auto-detect and wipe Windows C: drive only, replace with Arch."
echo " [6] MANUAL ADVANCED - Launch interactive cfdisk to resize/create partitions manually."
echo " [7] DROP TO SHELL   - Exit installer to a standard Arch Zsh terminal."
echo ""

while true; do
    read -p "Enter your choice (1-7): " USER_CHOICE
    if [[ "$USER_CHOICE" =~ ^[1-7]$ ]]; then
        break
    else
        echo "[WARNING] Invalid configuration track selected. Choose 1 through 7."
    fi
done

case $USER_CHOICE in
    1|2|6)
        if [ "$USER_CHOICE" = "1" ]; then echo "====== SAFE MULTI-BOOT (KEEPING EXISTING OS) ======"; fi
        if [ "$USER_CHOICE" = "2" ]; then echo "====== REPLACE LINUX (NUKING OLD OS) ======"; fi
        if [ "$USER_CHOICE" = "6" ]; then 
            echo "====== OPENING INTERACTIVE PARTITION WIZARD ======"
            cfdisk "$TARGET_DRIVE"
        fi
        
        echo -e "\n=========================================================="
        lsblk "$TARGET_DRIVE" -o NAME,SIZE,TYPE,FSTYPE
        echo "----------------------------------------------------------"
        
        while true; do
            read -p "Enter the exact partition to use for Arch ROOT (e.g., /dev/sda3): " ARCH_ROOT
            if [ -b "$ARCH_ROOT" ]; then
                if [ "$ARCH_ROOT" = "$TARGET_DRIVE" ]; then
                    echo "[CRITICAL ERROR] You selected the entire drive, not a partition! Try again."
                else
                    break
                fi
            else
                echo "[ERROR] Partition $ARCH_ROOT does not exist! Check your spelling."
            fi
        done

        if [ -d "/sys/firmware/efi" ]; then
            while true; do
                read -p "Enter your system's EFI partition path (e.g., /dev/sda1): " ARCH_EFI
                if [ -b "$ARCH_EFI" ]; then
                    if [ "$ARCH_EFI" = "$TARGET_DRIVE" ]; then
                        echo "[CRITICAL ERROR] You selected the entire drive! Try again."
                    else
                        break
                    fi
                else
                    echo "[ERROR] Partition $ARCH_EFI does not exist! Check your spelling."
                fi
            done
        fi
        
        if [ "$USER_CHOICE" = "2" ]; then
            echo -e "\n[WARNING] You are about to permanently erase $ARCH_ROOT!"
            read -p "Type 'NUKE' to confirm: " CONFIRM_NUKE
            if [ "$CONFIRM_NUKE" != "NUKE" ]; then
                echo "[ABORT] Canceled. Returning to shell."
                exit 1
            fi
        fi

        if [ "$USER_CHOICE" = "6" ]; then
            read -p "Would you like to format $ARCH_ROOT to ext4? (y/N): " FORMAT_ROOT
            if [[ "$FORMAT_ROOT" =~ ^[Yy]$ ]]; then mkfs.ext4 -F "$ARCH_ROOT"; fi
        else
            echo "[INFO] Formatting $ARCH_ROOT as EXT4..."
            mkfs.ext4 -F "$ARCH_ROOT"
        fi
        
        mount "$ARCH_ROOT" "$TARGET"
        
        if [ -d "/sys/firmware/efi" ]; then
            echo "[INFO] Safely mounting EFI partition..."
            mkdir -p "$TARGET/efi"
            umount "$ARCH_EFI" 2>/dev/null || true
            
            if [ "$USER_CHOICE" = "6" ]; then
                read -p "Would you like to format $ARCH_EFI as FAT32 (EFI)? (y/N): " FORMAT_EFI
                if [[ "$FORMAT_EFI" =~ ^[Yy]$ ]]; then
                    echo "[INFO] Formatting $ARCH_EFI as FAT32..."
                    mkfs.vfat -F 32 "$ARCH_EFI"
                fi
            fi

            mount "$ARCH_EFI" "$TARGET/efi"
        else
            mkdir -p "$TARGET/boot"
        fi
        
        if [ "$USER_CHOICE" = "6" ]; then
            read -p "Enable multi-boot OS detection (os-prober)? (Y/n): " MANUAL_PROBER
            if [[ "$MANUAL_PROBER" =~ ^[Nn]$ ]]; then GRUB_OS_PROBER="true"; else GRUB_OS_PROBER="false"; fi
        else
            GRUB_OS_PROBER="false"
        fi
        ;;
        
    3)
        echo "====== CRITICAL WARNING: NUKING ALL PARTITIONS ======"
        echo "Clearing partition blocks in 5 seconds... Press Ctrl+C to abort!"
        sleep 5
        if [ -d "/sys/firmware/efi" ]; then
            sgdisk --zap-all "$TARGET_DRIVE"
            sgdisk -n 1:0:+1G -t 1:ef00 -c 1:"EFI" "$TARGET_DRIVE"
            sgdisk -n 2:0:0   -t 2:8300 -c 2:"ROOT" "$TARGET_DRIVE"
            partprobe "$TARGET_DRIVE"
            sleep 2
            mkfs.vfat -F 32 "${TARGET_DRIVE}${PART_PREFIX}1"
            mkfs.ext4 -F "${TARGET_DRIVE}${PART_PREFIX}2"
            mount "${TARGET_DRIVE}${PART_PREFIX}2" "$TARGET"
            mkdir -p "$TARGET/boot"
            mount "${TARGET_DRIVE}${PART_PREFIX}1" "$TARGET/boot"
        else
            sgdisk --zap-all "$TARGET_DRIVE" &>/dev/null || true
            echo "label: dos" | sfdisk "$TARGET_DRIVE" &>/dev/null
            echo ", +" | sfdisk "$TARGET_DRIVE" --force &>/dev/null
            partprobe "$TARGET_DRIVE"
            sleep 2
            ARCH_ROOT="${TARGET_DRIVE}${PART_PREFIX}1"
            mkfs.ext4 -F "$ARCH_ROOT"
            mount "$ARCH_ROOT" "$TARGET"
            EFI_DIR="/boot"
        fi
        GRUB_OS_PROBER="true"
        ;;
    4)
        echo "====== PROCEEDING WITH SAFE WINDOWS AUTO-RESIZE ======"
        echo -e "\n[WARNING] This requires pre-existing UNALLOCATED SPACE on your drive."
        echo "If you did not manually shrink your Windows C: volume beforehand, ABORT NOW."
        read -p "Do you have free unallocated space verified on $TARGET_DRIVE? (Type 'YES' to proceed): " SPACE_CHECK
        if [ "$SPACE_CHECK" != "YES" ]; then
            echo "[ABORT] Action canceled. Shrink your drive volume inside Windows first."
            exit 1
        fi

        WIN_EFI=$(lsblk -ln -o NAME,FSTYPE "$TARGET_DRIVE" | grep vfat | head -n 1 | awk '{print "/dev/"$1}') || true
        if [ -z "$WIN_EFI" ]; then
            echo "[ERROR] Unable to locate an existing Windows EFI layout. Aborting."
            exit 1
        fi
        
        sgdisk --largest-new=0 "$TARGET_DRIVE"
        partprobe "$TARGET_DRIVE"
        sleep 2
        
        ARCH_ROOT=$(lsblk -ln -p -o NAME "$TARGET_DRIVE" | grep -E "^${TARGET_DRIVE}${PART_PREFIX}[0-9]+" | sort -V | tail -n 1)
        [ -z "$ARCH_ROOT" ] && { echo "[ERROR] Partition detection failed. Aborting."; exit 1; }
        
        mkfs.ext4 -F "$ARCH_ROOT"
        mount "$ARCH_ROOT" "$TARGET"
        
        mkdir -p "$TARGET/efi"
        mount "$WIN_EFI" "$TARGET/efi"
        
        GRUB_OS_PROBER="false"
        ;;
    5)
        echo "====== TARGET NUKE: HUNTING DOWN WINDOWS C: DRIVE ======"
        C_DRIVE=$(lsblk -b -n -o NAME,FSTYPE | grep ntfs | awk '{print $1}' | xargs -I {} lsblk -b -n -o NAME,SIZE /dev/{} 2>/dev/null | sort -k2 -n -r | head -n 1 | awk '{print "/dev/"$1}') || true
        if [ -z "$C_DRIVE" ]; then
            lsblk "$TARGET_DRIVE" -o NAME,SIZE,TYPE,FSTYPE
            read -p "Please type the target Windows partition manually (e.g., /dev/sda2): " C_DRIVE
        fi
        WIN_EFI=$(lsblk -ln -o NAME,FSTYPE "$TARGET_DRIVE" | grep vfat | head -n 1 | awk '{print "/dev/"$1}') || true
        echo -e "\n!!!!!!!!!!!!!!!!!!! DANGER ZONE !!!!!!!!!!!!!!!!!!!"
        echo "You are about to PERMANENTLY ERASE partition: $C_DRIVE"
        read -p "Type 'NUKE' to execute operation: " CONFIRM_NUKE
        if [ "$CONFIRM_NUKE" = "NUKE" ]; then
            echo "[INFO] Commencing target wipe on $C_DRIVE..."
            mkfs.ext4 -F "$C_DRIVE"
            mount "$C_DRIVE" "$TARGET"
            
            mkdir -p "$TARGET/efi"
            mount "$WIN_EFI" "$TARGET/efi"
            
            GRUB_OS_PROBER="true" 
        else
            echo "[ABORT] Safety lock engaged. Returning to terminal."
            exit 1
        fi
        ;;
    7)
        echo "[INFO] Exiting Arch Architect menu. Handing over shell access."
        exit 0
        ;;
esac

# =====================================================================
#              ADAPTIVE COMPONENT SELECTION ENGINE
# =====================================================================
clear
echo "=========================================================="
echo "          STEP 3: CUSTOM SOFTWARE CONFIGURATION            "
echo "=========================================================="
echo ""

if [ "$INSTALL_MODE" = "1" ]; then
    echo "[ONLINE MODE ACTIVATED] Full ecosystem available."
    echo "----------------------------------------------------------"
    echo "Select your primary web browser:"
    echo " [1] Zen Browser (Flatpak - Optimized Layout)"
    echo " [2] Firefox (Native - Stable Industry Standard)"
    echo " [3] Brave Browser (Flatpak - Privacy Engine)"
    echo " [4] Chromium (Native - Open Source Base)"
    echo " [5] None (Skip browser installation)"
    echo ""
    while true; do
        read -p "Enter browser choice (1-5): " BROWSER_CHOICE
        if [[ "$BROWSER_CHOICE" =~ ^[1-5]$ ]]; then break; else echo "[WARNING] Select an option from 1 to 5."; fi
    done
    echo ""
    read -p "Do you require the LibreOffice productivity suite? (y/N): " OFFICE_CHOICE
else
    echo "[OFFLINE MODE ACTIVATED] Restricting options to local ISO assets."
    echo "----------------------------------------------------------"
    echo "Select your pre-baked web browser install:"
    echo " [1] Firefox (Offline Native)"
    echo " [2] Chromium (Offline Native)"
    echo " [3] None (Skip browser installation)"
    echo ""
    while true; do
        read -p "Enter browser choice (1-3): " BROWSER_CHOICE
        if [[ "$BROWSER_CHOICE" =~ ^[1-3]$ ]]; then break; else echo "[WARNING] Select an option from 1 to 3."; fi
    done
    echo ""
    read -p "Do you require the pre-baked LibreOffice suite? (y/N): " OFFICE_CHOICE
fi

echo ""
echo "----------------------------------------------------------"
read -p "Would you like to apply the Hyper-Performance Matrix? (ZRAM, Fast Builds, Optimized I/O) [Y/n]: " PERF_CHOICE

# Process Queues
if [[ "$OFFICE_CHOICE" =~ ^[Yy]$ ]]; then
    CORE_PKGS="$CORE_PKGS libreoffice-fresh qt5-wayland qt6-wayland"
fi

if [ "$INSTALL_MODE" = "1" ]; then
    case $BROWSER_CHOICE in
        2) CORE_PKGS="$CORE_PKGS firefox" ;;
        4) CORE_PKGS="$CORE_PKGS chromium" ;;
    esac
else
    case $BROWSER_CHOICE in
        1) CORE_PKGS="$CORE_PKGS firefox" ;;
        2) CORE_PKGS="$CORE_PKGS chromium" ;;
    esac
fi

# Dynamically inject silicon microcode patches
if grep -q "AuthenticAMD" /proc/cpuinfo; then
    CORE_PKGS="$CORE_PKGS amd-ucode"
elif grep -q "GenuineIntel" /proc/cpuinfo; then
    CORE_PKGS="$CORE_PKGS intel-ucode"
fi

# =====================================================================
#        🎮 GRAPHICS DRIVER & HYBRID SWITCHEROO ENGINE
# =====================================================================
GPU_COUNT=0
if lspci 2>/dev/null | grep -iq nvidia; then 
    CORE_PKGS="$CORE_PKGS nvidia nvidia-utils"
    GPU_COUNT=$((GPU_COUNT + 1))
fi
if lspci 2>/dev/null | grep -iq amd; then 
    CORE_PKGS="$CORE_PKGS xf86-video-amdgpu"
    GPU_COUNT=$((GPU_COUNT + 1))
fi
if lspci 2>/dev/null | grep -iq intel; then 
    CORE_PKGS="$CORE_PKGS intel-media-driver"
    GPU_COUNT=$((GPU_COUNT + 1))
fi

if [ "$GPU_COUNT" -gt 1 ]; then
    echo "[INFO] Hybrid Graphics Core detected. Appending Switcheroo Control..."
    CORE_PKGS="$CORE_PKGS switcheroo-control"
fi

echo ""
echo "----------------------------------------------------------"
echo "Select your primary Graphical Desktop Workspace:"
echo " [1] Hyprland   (Modern, Hardware-Accelerated Tiling Manager)"
echo " [2] KDE Plasma (Feature-Rich, Traditional, Familiar Desktop)"
echo " [3] XFCE       (Lightweight, Ultra-Stable Core Matrix)"
echo "----------------------------------------------------------"
while true; do
    read -p "Enter Desktop choice (1-3): " DE_CHOICE
    if [[ "$DE_CHOICE" =~ ^[1-3]$ ]]; then break; else echo "[WARNING] Select a desktop workspace path from 1 to 3."; fi
done

case $DE_CHOICE in
    1) CORE_PKGS="$CORE_PKGS hyprland waybar kitty rofi xdg-desktop-portal-hyprland polkit-kde-agent" ;;
    2) CORE_PKGS="$CORE_PKGS plasma-desktop plasma-nm power-profiles-daemon kscreen" ;;
    3) CORE_PKGS="$CORE_PKGS xfce4 xfce4-goodies" ;;
esac

# =====================================================================
#              ADMINISTRATIVE ACCOUNT CONFIGURATION
# =====================================================================
echo ""
echo "----------------------------------------------------------"
echo "             SYSTEM IDENTITY & ACCOUNT CREATION            "
echo "----------------------------------------------------------"

read -p "Enter a name for this computer (Hostname): " system_hostname
system_hostname=$(printf '%s\n' "$system_hostname" | tr -cd 'a-zA-Z0-9-' | tr '[:upper:]' '[:lower:]')
system_hostname="${system_hostname#-}"
system_hostname="${system_hostname%-}"

if [ -z "$system_hostname" ]; then 
    system_hostname="arch-architect"
    echo "[WARNING] Input contained only invalid characters. Defaulting to: $system_hostname"
else
    echo "[INFO] Sanitized Hostname to standard format: $system_hostname"
fi

read -p "Enter new account username: " username
username=$(printf '%s\n' "$username" | tr -cd 'a-z0-9_')
if [ -z "$username" ]; then
    username="eadxm_user"
    echo "[WARNING] Input contained only invalid characters. Defaulting to: $username"
else
    echo "[INFO] Sanitized username to POSIX standard: $username"
fi

while true; do
    echo "Enter secure authentication password for $username:"
    read -r -s user_password
    echo ""
    if [ -n "$user_password" ]; then
        break
    else
        echo "[ERROR] Password cannot be empty. Try again."
    fi
done

# =====================================================================
#              HYBRID INSTALLATION EXECUTION MACHINE
# =====================================================================
clear

if [ "$INSTALL_MODE" = "2" ]; then
    echo "[INFO] Deploying base operating matrix using LOCAL OFFLINE CACHE..."
    mkdir -p "$TARGET/var/cache/pacman/pkg"
    mkdir -p "$TARGET/var/lib/pacman/sync"
    
    mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak || true
    echo "" > /etc/pacman.d/mirrorlist
    
    cp -n "$ISO_CACHE"/* "$TARGET/var/cache/pacman/pkg/" 2>/dev/null || true
    cp -r /var/lib/pacman/sync/* "$TARGET/var/lib/pacman/sync/" 2>/dev/null || true
    
    pacstrap -c -K "$TARGET" $CORE_PKGS
    
    mv /etc/pacman.d/mirrorlist.bak /etc/pacman.d/mirrorlist || true
else
    echo "[INFO] Deploying base operating matrix via NETWORK CONDUIT..."
    echo "[INFO] Syncing pacman databases and keys to ensure stable downloads..."
    timedatectl set-ntp true
    
    pacman-key --init || true
    pacman-key --populate archlinux || true
    pacman -Syu archlinux-keyring --noconfirm 
    
    trap - ERR 
    
    DOWNLOAD_SUCCESS=0
    while [ "$DOWNLOAD_SUCCESS" -eq 0 ]; do
        rm -f "$TARGET/var/lib/pacman/db.lck" 2>/dev/null || true
        
        if pacstrap -K "$TARGET" $CORE_PKGS; then
            DOWNLOAD_SUCCESS=1
        else
            echo -e "\n=========================================================="
            echo " [CRITICAL WARNING] Base installation failed!"
            echo "=========================================================="
            echo "Options: [1] Retry [2] Fix Terminal [3] Reboot"
            read -p "Select [1-3]: " FAIL_CHOICE
            
            if [ "$FAIL_CHOICE" = "2" ]; then
                /bin/zsh || true
            elif [ "$FAIL_CHOICE" = "3" ]; then
                umount -R "$TARGET" &>/dev/null || true
                reboot || true
                exit 1
            fi
        fi
    done
    trap 'error_handler $? $LINENO' ERR 
fi

genfstab -U "$TARGET" >> "$TARGET/etc/fstab"

# =====================================================================
#              EXECUTE CHROOT PROFILE PROVISIONING USER MATRIX
# =====================================================================
echo "[INFO] Configuring user credentials and group management rules..."

arch-chroot "$TARGET" useradd -m -G wheel -s /bin/bash "$username"
printf '%s:%s\n' "$username" "$user_password" | arch-chroot "$TARGET" chpasswd
printf '%s:%s\n' "root" "$user_password" | arch-chroot "$TARGET" chpasswd

printf '%s\n' "$system_hostname" > "$TARGET/etc/hostname"

cat <<EOF > "$TARGET/etc/hosts"
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${system_hostname}.localdomain   ${system_hostname}
EOF

mkdir -p "$TARGET/etc/sudoers.d"
echo "%wheel ALL=(ALL:ALL) ALL" > "$TARGET/etc/sudoers.d/wheel"
chmod 440 "$TARGET/etc/sudoers.d/wheel"

echo "en_US.UTF-8 UTF-8" > "$TARGET/etc/locale.gen"
arch-chroot "$TARGET" locale-gen
echo "LANG=en_US.UTF-8" > "$TARGET/etc/locale.conf"

# --- SMART KEYBOARD INHERITANCE ---
LIVE_KEYMAP=$(localectl status 2>/dev/null | grep "VC Keymap" | awk '{print $3}')
[ -z "$LIVE_KEYMAP" ] && LIVE_KEYMAP="us"
printf 'KEYMAP=%s\n' "$LIVE_KEYMAP" > "$TARGET/etc/vconsole.conf"
# ----------------------------------

# --- DYNAMIC TIMEZONE ENGINE ---
if [ "$INSTALL_MODE" = "1" ]; then
    DETECTED_TZ=$(curl -s --max-time 3 https://ipapi.co/timezone 2>/dev/null || true)
    if [ -n "$DETECTED_TZ" ] && [ -f "/usr/share/zoneinfo/$DETECTED_TZ" ]; then
        arch-chroot "$TARGET" ln -sf "/usr/share/zoneinfo/$DETECTED_TZ" /etc/localtime
    else
        arch-chroot "$TARGET" ln -sf /usr/share/zoneinfo/UTC /etc/localtime
    fi
else
    arch-chroot "$TARGET" ln -sf /usr/share/zoneinfo/UTC /etc/localtime
fi
arch-chroot "$TARGET" hwclock --systohc
# -------------------------------

# --- SEAMLESS WI-FI MIGRATION ENGINE ---
if [ "$INSTALL_MODE" = "1" ]; then
    mkdir -p "$TARGET/var/lib/iwd"
    cp -r /var/lib/iwd/* "$TARGET/var/lib/iwd/" 2>/dev/null || true
    mkdir -p "$TARGET/etc/NetworkManager/conf.d"
    echo -e "[device]\nwifi.backend=iwd" > "$TARGET/etc/NetworkManager/conf.d/wifi_backend.conf"
fi
# ---------------------------------------

echo "[INFO] Enabling hardware daemon services..."
arch-chroot "$TARGET" systemctl enable sddm.service NetworkManager.service iwd.service bluetooth.service systemd-timesyncd.service

if [[ "$CORE_PKGS" == *"switcheroo-control"* ]]; then
    arch-chroot "$TARGET" systemctl enable switcheroo-control.service || true
fi

if [ "$INSTALL_MODE" = "1" ]; then
    arch-chroot "$TARGET" systemctl enable reflector.timer || true
fi

mkdir -p "$TARGET/etc/bluetooth"
echo -e "\n[Policy]\nAutoEnable=true" >> "$TARGET/etc/bluetooth/main.conf"

echo "[INFO] Injecting terminal cosmetics..."
cat << 'EOF' >> "$TARGET/home/$username/.bashrc"
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias ip='ip -color=auto'
alias pacman='sudo pacman --color auto'
alias update='sudo pacman -Syu'
PS1='\[\e[1;36m\]\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ '
EOF
arch-chroot "$TARGET" chown -R "$username:$username" "/home/$username"

# =====================================================================
#         HIGH-PERFORMANCE SYSTEM POWER-CONFIGURATIONS
# =====================================================================
if [[ "$PERF_CHOICE" =~ ^[Yy]$ || -z "$PERF_CHOICE" ]]; then
    arch-chroot "$TARGET" systemctl enable earlyoom.service || true
    sed -i 's/#MAKEFLAGS="-j2"/MAKEFLAGS="-j$(nproc)"/' "$TARGET/etc/makepkg.conf"
    sed -i 's/^COMPRESSZST=.*/COMPRESSZST=(zstd -c -T0 -)/' "$TARGET/etc/makepkg.conf"
    
    # PATCH: Portable printf-based config injection
    printf 'ParallelDownloads = 10\nColor\nILoveCandy\n' >> "$TARGET/etc/pacman.conf"

    cat <<EOF > "$TARGET/etc/systemd/zram-generator.conf"
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
EOF
    
    sed -i 's/#DefaultTimeoutStopSec=90s/DefaultTimeoutStopSec=15s/' "$TARGET/etc/systemd/system.conf"
    
    if [ "$(lsblk -nd -o ROTA "$TARGET_DRIVE" | head -n 1)" = "0" ]; then
        arch-chroot "$TARGET" systemctl enable fstrim.timer || true
    else
        mkdir -p "$TARGET/etc/udev/rules.d"
        echo 'ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"' >> "$TARGET/etc/udev/rules.d/60-scheduler.rules"
    fi
fi

echo "GRUB_DISABLE_OS_PROBER=$GRUB_OS_PROBER" >> "$TARGET/etc/default/grub"

echo "[INFO] Executing system hardware architecture validation routines..."
if [ -d "/sys/firmware/efi" ]; then
    # DYNAMIC PATH RESOLUTION
    [ -d "$TARGET/efi" ] && EFI_DIR="/efi" || EFI_DIR="/boot"
    arch-chroot "$TARGET" grub-install --target=x86_64-efi --efi-directory="$EFI_DIR" --bootloader-id=ArchLinux --recheck
else
    arch-chroot "$TARGET" grub-install --target=i386-pc "$TARGET_DRIVE" --recheck
fi

# OS-PROBER
if [ "$GRUB_OS_PROBER" = "false" ]; then
    WIN_PART=$(lsblk -b -n -o NAME,FSTYPE | grep ntfs | awk '{print $1}' | xargs -I {} lsblk -b -n -o NAME,SIZE /dev/{} 2>/dev/null | sort -k2 -n -r | head -n 1 | awk '{print "/dev/"$1}') || true
    if [ -n "$WIN_PART" ]; then
        mkdir -p "$TARGET/mnt/win_temp"
        mount -t ntfs-3g "$WIN_PART" "$TARGET/mnt/win_temp" -o ro || true
    fi
fi

arch-chroot "$TARGET" grub-mkconfig -o /boot/grub/grub.cfg

[ "$GRUB_OS_PROBER" = "false" ] && [ -n "$WIN_PART" ] && umount "$TARGET/mnt/win_temp" || true

# =====================================================================
#      CONTAINER SANDBOX PATCH (First-Boot Systemd Flatpak Engine)
# =====================================================================
if [ "$INSTALL_MODE" = "1" ]; then
    if [ "$BROWSER_CHOICE" = "1" ]; then FLATPAK_APP="app.zen_browser.zen"; fi
    if [ "$BROWSER_CHOICE" = "3" ]; then FLATPAK_APP="com.brave.Browser"; fi
    
    if [ -n "$FLATPAK_APP" ]; then
        cat <<EOF > "$TARGET/etc/systemd/system/architect-flatpak.service"
[Unit]
Description=Arch Architect Container Provisioning
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStartPre=/bin/sh -c 'until curl -sI https://flathub.org >/dev/null; do sleep 2; done'
ExecStartPre=/usr/bin/flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
ExecStart=/bin/bash -c 'for i in {1..5}; do /usr/bin/flatpak install flathub $FLATPAK_APP -y && break || sleep 15; done; /usr/bin/systemctl disable architect-flatpak.service'

[Install]
WantedBy=multi-user.target
EOF
        arch-chroot "$TARGET" systemctl enable architect-flatpak.service
    fi
fi

echo "=========================================================="
echo "   EADXM'S ARCH COMPILED! REBOOTING IN 5 SECONDS...       "
echo "=========================================================="
sleep 5
trap - ERR
reboot || true
