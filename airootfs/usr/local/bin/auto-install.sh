#!/bin/bash

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
    
    if [ "$FAULT_CHOICE" == "2" ]; then
        echo "[INFO] Handing over root bash console. Type 'exit' to return."
        /bin/zsh
    fi
    
    echo "[INFO] Safely unmounting storage arrays before exit..."
    umount -R /mnt &>/dev/null
    swapoff -a &>/dev/null
    echo "[INFO] Rebooting machine..."
    sleep 2
    reboot
    exit $exit_code
}

trap 'error_handler $? $LINENO' ERR

clear
echo "=========================================================="
echo "          EADXM'S AUTOMATED ARCH ARCHITECT v1.3.3         "
echo "=========================================================="
echo ""
echo "Choose your connection architecture:"
echo " [1] ONLINE INSTALL - Download the absolute latest packages & full browser matrix."
echo " [2] OFFLINE INSTALL - 100% Air-gapped deployment using pre-baked ISO assets."
echo ""

while true; do
    read -p "Select mode (1-2): " INSTALL_MODE
    if [[ "$INSTALL_MODE" == "1" || "$INSTALL_MODE" == "2" ]]; then
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
CORE_PKGS="base linux linux-firmware grub efibootmgr os-prober ntfs-3g networkmanager bluez bluez-utils blueman pipewire pipewire-pulse wireplumber brightnessctl flatpak xorg-server sddm sudo zram-generator earlyoom reflector ttf-dejavu ttf-liberation noto-fonts noto-fonts-emoji"

# =====================================================================
#              DYNAMIC HARDWARE DRIVE DETECTOR & PRE-FLIGHT
# =====================================================================
clear
echo "=========================================================="
echo "                TARGET DISK SELECTION MODULE               "
echo "=========================================================="
echo "[INFO] Scanning for available block storage devices..."
echo "----------------------------------------------------------"
lsblk -d -o NAME,SIZE,MODEL,TYPE | grep -E "disk|nvme|loop|mmc"
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
if [ "$INSTALL_MODE" == "1" ]; then
    while true; do
        clear
        echo "=========================================================="
        echo "              WIRELESS CONNECTION MANAGEMENT              "
        echo "=========================================================="
        echo "[INFO] Scanning for nearby Wi-Fi networks..."
        echo "----------------------------------------------------------"
        systemctl start NetworkManager &>/dev/null
        sleep 2
        nmcli --fields SSID,BARS,SECURITY device wifi list
        echo "----------------------------------------------------------"
        echo "Type the name (SSID) of your network to connect."
        echo "Or type 'CANCEL' to abort network configuration."
        echo "----------------------------------------------------------"
        read -p "SSID Selection: " WIFI_SSID
        
        if [ "$WIFI_SSID" == "CANCEL" ] || [ -z "$WIFI_SSID" ]; then
            echo -e "\n[WARNING] Wi-Fi configuration aborted."
            read -p "Drop down and continue as OFFLINE installation? (y/N): " ESCAPE_CHOICE
            if [[ "$ESCAPE_CHOICE" =~ ^[Yy]$ ]]; then
                INSTALL_MODE="2"
                sleep 2
                break
            else
                continue
            fi
        fi
        
        read -r -s -p "Enter Wi-Fi Password (leave blank for Open Network): " WIFI_PASS
        echo -e "\n\n[INFO] Authenticating and linking with $WIFI_SSID..."
        
        if [ -z "$WIFI_PASS" ]; then
            nmcli device wifi connect "$WIFI_SSID" &>/dev/null
        else
            nmcli device wifi connect "$WIFI_SSID" password "$WIFI_PASS" &>/dev/null
        fi
        
        if [ $? -eq 0 ]; then
            echo "[SUCCESS] Connected successfully! Internet connection established."
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
echo " [1] DUAL BOOT - Keep Windows, bypass the 100MB EFI restriction safely."
echo " [2] HARD NUKE - Wipe the drive, build an adaptive firmware layout, clean install."
echo " [3] MANUAL ADVANCED - Launch interactive cfdisk to resize/create partitions manually."
echo " [4] TARGET NUKE - Auto-detect and wipe Windows C: drive only, replace with Arch."
echo " [5] DROP TO SHELL - Exit installer to a standard Arch Zsh terminal."
echo ""
read -p "Enter your choice (1-5): " USER_CHOICE

case $USER_CHOICE in
    1)
        echo "====== PROCEEDING WITH SAFE DUAL-BOOT CONFIGURATION ======"
        echo -e "\n[WARNING] Dual-Boot requires pre-existing UNALLOCATED SPACE on your drive."
        echo "If you did not manually shrink your Windows C: volume beforehand, ABORT NOW."
        read -p "Do you have free unallocated space verified on $TARGET_DRIVE? (Type 'YES' to proceed): " SPACE_CHECK
        if [ "$SPACE_CHECK" != "YES" ]; then
            echo "[ABORT] Action canceled. Shrink your drive volume inside Windows first."
            exit 1
        fi

        WIN_EFI=$(lsblk -ln -o NAME,FSTYPE "$TARGET_DRIVE" | grep vfat | head -n 1 | awk '{print "/dev/"$1}')
        if [ -z "$WIN_EFI" ]; then
            echo "[ERROR] Unable to locate an existing Windows EFI layout. Aborting."
            exit 1
        fi
        
        echo ", +" | sfdisk "$TARGET_DRIVE" --force --no-reread &>/dev/null
        partprobe "$TARGET_DRIVE"
        sleep 2
        
        ARCH_ROOT=$(lsblk -ln -p -o NAME "$TARGET_DRIVE" | grep -E "^${TARGET_DRIVE}${PART_PREFIX}[0-9]+" | sort -V | tail -n 1)
        
        mkfs.ext4 -F "$ARCH_ROOT"
        mount "$ARCH_ROOT" $TARGET
        mkdir -p $TARGET/efi
        mkdir -p $TARGET/boot
        mount "$WIN_EFI" $TARGET/efi
        EFI_DIR="/efi"
        GRUB_OS_PROBER="false"
        ;;
    2)
        echo "====== CRITICAL WARNING: NUKING ALL WINDOWS PARTITIONS ======"
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
            mount "${TARGET_DRIVE}${PART_PREFIX}2" $TARGET
            mkdir -p $TARGET/boot
            mount "${TARGET_DRIVE}${PART_PREFIX}1" $TARGET/boot
            EFI_DIR="/boot"
        else
            sgdisk --zap-all "$TARGET_DRIVE" &>/dev/null || true
            echo ", +" | sfdisk "$TARGET_DRIVE" --force &>/dev/null
            partprobe "$TARGET_DRIVE"
            sleep 2
            ARCH_ROOT="${TARGET_DRIVE}${PART_PREFIX}1"
            mkfs.ext4 -F "$ARCH_ROOT"
            mount "$ARCH_ROOT" $TARGET
            EFI_DIR="/boot"
        fi
        GRUB_OS_PROBER="true"
        ;;
    3)
        echo "====== OPENING INTERACTIVE PARTITION WIZARD ======"
        cfdisk "$TARGET_DRIVE"
        echo -e "\n=========================================================="
        lsblk "$TARGET_DRIVE" -o NAME,SIZE,TYPE,FSTYPE
        echo "----------------------------------------------------------"
        read -p "Enter the exact partition to use for Arch ROOT (e.g., /dev/sda3): " ARCH_ROOT
        if [ -d "/sys/firmware/efi" ]; then
            read -p "Enter your system's EFI partition path (e.g., /dev/sda1): " ARCH_EFI
        fi
        read -p "Would you like to format $ARCH_ROOT to ext4? (y/N): " FORMAT_ROOT
        if [[ "$FORMAT_ROOT" =~ ^[Yy]$ ]]; then
            mkfs.ext4 -F "$ARCH_ROOT"
        fi
        mount "$ARCH_ROOT" $TARGET
        if [ -d "/sys/firmware/efi" ]; then
            mkdir -p $TARGET/boot
            mount "$ARCH_EFI" $TARGET/boot
            EFI_DIR="/boot"
        else
            EFI_DIR="/boot"
        fi
        read -p "Enable dual-boot Windows detection (os-prober)? (y/N): " MANUAL_PROBER
        if [[ "$MANUAL_PROBER" =~ ^[Yy]$ ]]; then
            GRUB_OS_PROBER="false"
        else
            GRUB_OS_PROBER="true"
        fi
        ;;
    4)
        echo "====== TARGET NUKE: HUNTING DOWN WINDOWS C: DRIVE ======"
        C_DRIVE=$(lsblk -b -n -o NAME,FSTYPE "$TARGET_DRIVE" | grep ntfs | awk '{print $1}' | xargs -I {} lsblk -b -n -o NAME,SIZE /dev/{} 2>/dev/null | sort -k2 -n -r | head -n 1 | awk '{print "/dev/"$1}')
        if [ -z "$C_DRIVE" ]; then
            lsblk "$TARGET_DRIVE" -o NAME,SIZE,TYPE,FSTYPE
            read -p "Please type the target Windows partition manually (e.g., /dev/sda2): " C_DRIVE
        fi
        WIN_EFI=$(lsblk -ln -o NAME,FSTYPE "$TARGET_DRIVE" | grep vfat | head -n 1 | awk '{print "/dev/"$1}')
        echo -e "\n!!!!!!!!!!!!!!!!!!! DANGER ZONE !!!!!!!!!!!!!!!!!!!"
        echo "You are about to PERMANENTLY ERASE partition: $C_DRIVE"
        read -p "Type 'NUKE' to execute operation: " CONFIRM_NUKE
        if [ "$CONFIRM_NUKE" = "NUKE" ]; then
            echo "[INFO] Commencing target wipe on $C_DRIVE..."
            mkfs.ext4 -F "$C_DRIVE"
            mount "$C_DRIVE" $TARGET
            mkdir -p $TARGET/efi
            mkdir -p $TARGET/boot
            mount "$WIN_EFI" $TARGET/efi
            EFI_DIR="/efi"
            GRUB_OS_PROBER="true"
        else
            echo "[ABORT] Safety lock engaged. Returning to terminal."
            exit 1
        fi
        ;;
    5)
        echo "[INFO] Exiting Arch Architect menu. Handing over shell access."
        exit 0
        ;;
    *)
        echo "[ERROR] Invalid selection. Aborting script execution."
        exit 1
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

if [ "$INSTALL_MODE" == "1" ]; then
    echo "[ONLINE MODE ACTIVATED] Full ecosystem available."
    echo "----------------------------------------------------------"
    echo "Select your primary web browser:"
    echo " [1] Zen Browser (Flatpak - Optimized Layout)"
    echo " [2] Firefox (Native - Stable Industry Standard)"
    echo " [3] Brave Browser (Flatpak - Privacy Engine)"
    echo " [4] Chromium (Native - Open Source Base)"
    echo " [5] None (Skip browser installation)"
    echo ""
    read -p "Enter browser choice (1-5): " BROWSER_CHOICE
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
    read -p "Enter browser choice (1-3): " BROWSER_CHOICE
    echo ""
    read -p "Do you require the pre-baked LibreOffice suite? (y/N): " OFFICE_CHOICE
fi

echo ""
echo "----------------------------------------------------------"
read -p "Would you like to apply the Hyper-Performance Matrix? (ZRAM, Fast Builds, Optimized I/O) [Y/n]: " PERF_CHOICE

# Process Queues
if [[ "$OFFICE_CHOICE" =~ ^[Yy]$ ]]; then
    CORE_PKGS="$CORE_PKGS libreoffice-fresh"
fi

if [ "$INSTALL_MODE" == "1" ]; then
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
if lspci | grep -iq nvidia; then 
    CORE_PKGS="$CORE_PKGS nvidia nvidia-utils"
    ((GPU_COUNT++))
fi
if lspci | grep -iq amd; then 
    CORE_PKGS="$CORE_PKGS xf86-video-amdgpu"
    ((GPU_COUNT++))
fi
if lspci | grep -iq intel; then 
    CORE_PKGS="$CORE_PKGS xf86-video-intel intel-media-driver"
    ((GPU_COUNT++))
fi

# If multiple GPU architectures are mapped, add the D-Bus hardware switch controller
if [ "$GPU_COUNT" -gt 1 ]; then
    echo "[INFO] Hybrid Graphics Core detected. Appending Switcheroo Control..."
    CORE_PKGS="$CORE_PKGS switcheroo-control"
fi

echo ""
echo "----------------------------------------------------------"
echo "Select your primary Graphical Desktop Workspace:"
echo " [1] Hyprland    (Modern, Hardware-Accelerated Tiling Manager)"
echo " [2] KDE Plasma (Feature-Rich, Traditional, Familiar Desktop)"
echo " [3] XFCE        (Lightweight, Ultra-Stable Core Matrix)"
echo "----------------------------------------------------------"
read -p "Enter Desktop choice (1-3): " DE_CHOICE

case $DE_CHOICE in
    1) CORE_PKGS="$CORE_PKGS hyprland waybar kitty rofi-wayland xdg-desktop-portal-hyprland" ;;
    2) CORE_PKGS="$CORE_PKGS plasma-desktop plasma-nm power-profiles-daemon kscreen" ;;
    3) CORE_PKGS="$CORE_PKGS xfce4 xfce4-goodies" ;;
    *) CORE_PKGS="$CORE_PKGS xfce4 xfce4-goodies" ;;
esac

# =====================================================================
#              ADMINISTRATIVE ACCOUNT CONFIGURATION
# =====================================================================
echo ""
echo "----------------------------------------------------------"
echo "             SYSTEM IDENTITY & ACCOUNT CREATION            "
echo "----------------------------------------------------------"
read -p "Enter a name for this computer (Hostname): " system_hostname
if [ -z "$system_hostname" ]; then system_hostname="arch-architect"; fi

read -p "Enter new account username: " username
if [ -z "$username" ]; then
    username="eadxm_user"
    echo "[INFO] Defaulting account name to: $username"
fi

echo "Enter secure authentication password for $username:"
read -r -s user_password
echo ""

# =====================================================================
#              HYBRID INSTALLATION EXECUTION MACHINE
# =====================================================================
clear

if [ "$INSTALL_MODE" == "2" ]; then
    echo "[INFO] Deploying base operating matrix using LOCAL OFFLINE CACHE..."
    mkdir -p $TARGET/var/cache/pacman/pkg
    cp -n $ISO_CACHE/* $TARGET/var/cache/pacman/pkg/
    pacstrap -c -K $TARGET $CORE_PKGS
else
    echo "[INFO] Deploying base operating matrix via NETWORK CONDUIT..."
    pacstrap -K $TARGET $CORE_PKGS
fi

# =====================================================================
#              EXECUTE CHROOT PROFILE PROVISIONING USER MATRIX
# =====================================================================
echo "[INFO] Configuring user credentials and group management rules..."

arch-chroot $TARGET useradd -m -G wheel -s /bin/bash "$username"
echo "$username:$user_password" | arch-chroot $TARGET chpasswd
echo "root:$user_password" | arch-chroot $TARGET chpasswd

echo "$system_hostname" > $TARGET/etc/hostname
echo -e "127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.1.1\t$system_hostname.localdomain\t$system_hostname" > $TARGET/etc/hosts

sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' $TARGET/etc/sudoers

echo "en_US.UTF-8 UTF-8" > $TARGET/etc/locale.gen
arch-chroot $TARGET locale-gen
echo "LANG=en_US.UTF-8" > $TARGET/etc/locale.conf
arch-chroot $TARGET ln -sf /usr/share/zoneinfo/UTC /etc/localtime
arch-chroot $TARGET hwclock --systohc

if [ "$INSTALL_MODE" == "1" ]; then
    echo "[INFO] Transferring Network Authentication Matrix to Target..."
    mkdir -p $TARGET/etc/NetworkManager/system-connections/
    cp -r /etc/NetworkManager/system-connections/* $TARGET/etc/NetworkManager/system-connections/ 2>/dev/null || true
fi

echo "[INFO] Enabling hardware daemon services..."
arch-chroot $TARGET systemctl enable sddm.service || true
arch-chroot $TARGET systemctl enable NetworkManager.service || true
arch-chroot $TARGET systemctl enable bluetooth.service || true
arch-chroot $TARGET systemctl enable systemd-timesyncd.service || true

# Conditional check for multi-GPU switcher service execution
if [[ "$CORE_PKGS" == *"switcheroo-control"* ]]; then
    echo "[INFO] Activating Multi-GPU Switcheroo Interface..."
    arch-chroot $TARGET systemctl enable switcheroo-control.service || true
fi

if [ "$INSTALL_MODE" == "1" ]; then
    arch-chroot $TARGET systemctl enable reflector.timer || true
fi

mkdir -p $TARGET/etc/bluetooth
echo -e "\n[Policy]\nAutoEnable=true" >> $TARGET/etc/bluetooth/main.conf

echo "[INFO] Injecting customized terminal profile cosmetics..."
cat << 'EOF' >> $TARGET/home/$username/.bashrc

# ==========================================
# Arch Architect Custom Terminal Cosmetics
# ==========================================
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias ip='ip -color=auto'
alias pacman='sudo pacman --color auto'
alias update='sudo pacman -Syu'
PS1='\[\e[1;36m\]\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ '
EOF
arch-chroot $TARGET chown -R $username:$username /home/$username

# =====================================================================
#          HIGH-PERFORMANCE SYSTEM POWER-CONFIGURATIONS
# =====================================================================
if [[ "$PERF_CHOICE" =~ ^[Yy]$ || -z "$PERF_CHOICE" ]]; then
    echo "[INFO] Injecting internal hardware and package compiler speed enhancements..."
    arch-chroot $TARGET systemctl enable earlyoom.service || true

    sed -i 's/#MAKEFLAGS="-j2"/MAKEFLAGS="-j$(nproc)"/' $TARGET/etc/makepkg.conf
    sed -i 's/^COMPRESSZST=.*/COMPRESSZST=(zstd -c -T0 -)/' $TARGET/etc/makepkg.conf
    
    # --- EDITED THESE TWO LINES BELOW ---
    sed -i 's/^#\?ParallelDownloads.*/ParallelDownloads = 10/' $TARGET/etc/pacman.conf
    sed -i 's/^#\?Color.*/Color\nILoveCandy/' $TARGET/etc/pacman.conf
    # ------------------------------------

    echo -e "[zram0]\nzram-size = ram / 2\ncompression-algorithm = zstd" > $TARGET/etc/systemd/zram-generator.conf
    sed -i 's/#DefaultTimeoutStopSec=90s/DefaultTimeoutStopSec=15s/' $TARGET/etc/systemd/system.conf
    DRIVE_NAME=$(basename "$TARGET_DRIVE")
    IS_ROTATIONAL=$(cat /sys/block/$DRIVE_NAME/queue/rotational 2>/dev/null || echo "1")

    if [ "$IS_ROTATIONAL" == "0" ]; then
        echo "[INFO] Solid State Core Verified. Activating system TRIM triggers..."
        arch-chroot $TARGET systemctl enable fstrim.timer || true
    else
        echo "[INFO] Spinning Hard Disk Detected. Shifting device IO Scheduler to BFQ for smoothness..."
        mkdir -p $TARGET/etc/udev/rules.d
        echo 'ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"' >> $TARGET/etc/udev/rules.d/60-scheduler.rules
    fi

    # === ADDED HERE ===
    if [ -f "/etc/udev/rules.d/90-backlight.rules" ]; then
        echo "[INFO] Deploying hardware backlight rules to target system..."
        mkdir -p $TARGET/etc/udev/rules.d
        cp /etc/udev/rules.d/90-backlight.rules $TARGET/etc/udev/rules.d/
    fi
fi

echo "GRUB_DISABLE_OS_PROBER=$GRUB_OS_PROBER" >> $TARGET/etc/default/grub

echo "[INFO] Executing system hardware architecture validation routines..."
if [ -d "/sys/firmware/efi" ]; then
    arch-chroot $TARGET grub-install --target=x86_64-efi --efi-directory=$EFI_DIR --bootloader-id=ArchLinux --recheck
else
    arch-chroot $TARGET grub-install --target=i386-pc "$TARGET_DRIVE" --recheck
fi
arch-chroot $TARGET grub-mkconfig -o /boot/grub/grub.cfg

# =====================================================================
#      CONTAINER SANDBOX PATCH (First-Boot Systemd Flatpak Engine)
# =====================================================================
if [ "$INSTALL_MODE" == "1" ]; then
    if [ "$BROWSER_CHOICE" == "1" ]; then FLATPAK_APP="app.zen_browser.zen"; fi
    if [ "$BROWSER_CHOICE" == "3" ]; then FLATPAK_APP="com.brave.Browser"; fi
    
    if [ -n "$FLATPAK_APP" ]; then
        echo "[INFO] Staging Flatpak First-Boot Provisioning Background Service..."
        cat <<EOF > $TARGET/etc/systemd/system/architect-flatpak.service
[Unit]
Description=Arch Architect Container Provisioning
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
ExecStart=/usr/bin/flatpak install flathub $FLATPAK_APP -y
ExecStartPost=/usr/bin/systemctl disable architect-flatpak.service

[Install]
WantedBy=multi-user.target
EOF
        arch-chroot $TARGET systemctl enable architect-flatpak.service
    fi
fi

genfstab -U $TARGET >> $TARGET/etc/fstab

echo "=========================================================="
echo "   EADXM'S ARCH COMPILED! REBOOTING IN 5 SECONDS...       "
echo "=========================================================="
sleep 5
reboot
