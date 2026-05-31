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

# Bind the error handler to any command returning a non-zero status
trap 'error_handler $? $LINENO' ERR

# Clear screen for a clean, custom user interface
clear
echo "=========================================================="
echo "          EADXM'S AUTOMATED ARCH ARCHITECT                "
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

# Base system package matrix (Added 'sudo' and 'sddm' as base requirements)
CORE_PKGS="base linux linux-firmware grub efibootmgr os-prober ntfs-3g networkmanager bluez bluez-utils blueman pipewire pipewire-pulse wireplumber brightnessctl flatpak xorg-server sddm sudo"

# =====================================================================
#              DYNAMIC HARDWARE DRIVE DETECTOR & PRE-FLIGHT
# =====================================================================
clear
echo "=========================================================="
echo "                TARGET DISK SELECTION MODULE               "
echo "=========================================================="
echo "[INFO] Scanning for available block storage devices..."
echo "----------------------------------------------------------"
lsblk -d -o NAME,SIZE,MODEL,TYPE | grep -E "disk|nvme"
echo "----------------------------------------------------------"

while true; do
    read -p "Type your destination installation disk (e.g., /dev/sda or /dev/nvme0n1): " TARGET_DRIVE
    if [ -b "$TARGET_DRIVE" ]; then
        break
    else
        echo "[ERROR] Device path '$TARGET_DRIVE' does not exist or is not a block device. Try again."
    fi
done

# Safe Pre-Flight Cleanup: Ensure drive targets aren't locked by ghost mounts
echo "[INFO] Clearing environmental block locks..."
umount -R /mnt &>/dev/null || true

# Smart Partition Naming Generator for NVMe/SDA drive compliance
if [[ "$TARGET_DRIVE" == *"nvme"* ]]; then
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
        
        # Wake up NetworkManager daemon if it's sleeping in the live ISO
        systemctl start NetworkManager &>/dev/null
        sleep 2
        
        # Display available SSIDs neatly
        nmcli --fields SSID,BARS,SECURITY device wifi list
        echo "----------------------------------------------------------"
        echo "Type the name (SSID) of your network to connect."
        echo "Or type 'CANCEL' to abort network configuration."
        echo "----------------------------------------------------------"
        read -p "SSID Selection: " WIFI_SSID
        
        if [ "$WIFI_SSID" == "CANCEL" ] || [ -z "$WIFI_SSID" ]; then
            echo -e "\n[WARNING] Wi-Fi configuration aborted."
            echo " [1] Try connecting to Wi-Fi again"
            echo " [2] Drop down and continue as an OFFLINE installation"
            echo ""
            read -p "Selection (1-2): " ESCAPE_CHOICE
            if [ "$ESCAPE_CHOICE" == "2" ]; then
                echo "[INFO] Pivoting installer layout to Offline Mode..."
                INSTALL_MODE="2"
                sleep 2
                break
            else
                continue
            fi
        fi
        
        # Request password and attempt connection safely
        read -s -p "Enter Wi-Fi Password: " WIFI_PASS
        echo -e "\n\n[INFO] Authenticating and linking with $WIFI_SSID..."
        
        # Explicitly passing password arguments cleanly to stop CLI hanging
        if nmcli device wifi connect "$WIFI_SSID" password "$WIFI_PASS" &>/dev/null; then
            echo "[SUCCESS] Connected successfully! Internet connection established."
            sleep 2
            break
        else
            echo -e "\n[ERROR] Connection failed. Incorrect password or poor signal."
            echo " [1] Try connecting again"
            echo " [2] Drop down and continue as an OFFLINE installation"
            echo ""
            read -p "Selection (1-2): " ESCAPE_CHOICE
            if [ "$ESCAPE_CHOICE" == "2" ]; then
                echo "[INFO] Pivoting installer layout to Offline Mode..."
                INSTALL_MODE="2"
                sleep 2
                break
            fi
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
echo " [2] HARD NUKE - Wipe the drive, build a spacious 1GB EFI, clean install."
echo " [3] MANUAL ADVANCED - Launch interactive cfdisk to resize/create partitions manually."
echo " [4] TARGET NUKE - Auto-detect and wipe Windows C: drive only, replace with Arch."
echo " [5] DROP TO SHELL - Exit installer to a standard Arch Zsh terminal."
echo ""
read -p "Enter your choice (1-5): " USER_CHOICE

case $USER_CHOICE in
    1)
        echo "====== PROCEEDING WITH SAFE DUAL-BOOT CONFIGURATION ======"
        WIN_EFI=$(lsblk -ln -o NAME,FSTYPE "$TARGET_DRIVE" | grep vfat | head -n 1 | awk '{print "/dev/"$1}')
        if [ -z "$WIN_EFI" ]; then
            echo "[ERROR] Unable to locate an existing Windows EFI layout. Aborting."
            exit 1
        fi
        echo ", +" | sfdisk "$TARGET_DRIVE" --force --no-reread &>/dev/null
        ARCH_ROOT="${TARGET_DRIVE}${PART_PREFIX}3"
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
        GRUB_OS_PROBER="true"
        ;;
    3)
        echo "====== OPENING INTERACTIVE PARTITION WIZARD ======"
        cfdisk "$TARGET_DRIVE"
        echo -e "\n=========================================================="
        lsblk "$TARGET_DRIVE" -o NAME,SIZE,TYPE,FSTYPE
        echo "----------------------------------------------------------"
        read -p "Enter the exact partition to use for Arch ROOT (e.g., /dev/sda3): " ARCH_ROOT
        read -p "Enter your system's EFI partition path (e.g., /dev/sda1): " ARCH_EFI
        read -p "Would you like to format $ARCH_ROOT to ext4? (y/N): " FORMAT_ROOT
        if [[ "$FORMAT_ROOT" =~ ^[Yy]$ ]]; then
            mkfs.ext4 -F "$ARCH_ROOT"
        fi
        mount "$ARCH_ROOT" $TARGET
        mkdir -p $TARGET/boot
        mount "$ARCH_EFI" $TARGET/boot
        EFI_DIR="/boot"
        read -p "Enable dual-boot Windows detection (os-prober)? (y/N): " MANUAL_PROBER
        if [[ "$MANUAL_PROBER" =~ ^[Yy]$ ]]; then
            GRUB_OS_PROBER="false"
        else
            GRUB_OS_PROBER="true"
        fi
        ;;
    4)
        echo "====== TARGET NUKE: HUNTING DOWN WINDOWS C: DRIVE ======"
        C_DRIVE=$(blkid -o device -t TYPE=ntfs | head -n 1)
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
    echo "Do you require the LibreOffice productivity suite (~400MB space)?"
    echo " [1] Yes, install LibreOffice-Fresh"
    echo " [2] No, keep the build clean and light"
    echo ""
    read -p "Enter office suite choice (1-2): " OFFICE_CHOICE
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
    echo "Do you require the pre-baked LibreOffice suite?"
    echo " [1] Yes, install LibreOffice-Fresh offline"
    echo " [2] No, keep the build clean and light"
    echo ""
    read -p "Enter office suite choice (1-2): " OFFICE_CHOICE
fi

# Process Office Suite Queues
if [ "$OFFICE_CHOICE" == "1" ]; then
    CORE_PKGS="$CORE_PKGS libreoffice-fresh"
fi

# Process Browser Queues based on Architecture selection
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

# Automatically bundle matching hardware drivers to execution string
if lspci | grep -iq nvidia; then
    CORE_PKGS="$CORE_PKGS nvidia nvidia-utils"
elif lspci | grep -iq amd; then
    CORE_PKGS="$CORE_PKGS xf86-video-amdgpu"
elif lspci | grep -iq intel; then
    CORE_PKGS="$CORE_PKGS xf86-video-intel intel-media-driver"
fi

# =====================================================================
#             DESKTOP ENVIRONMENT SELECTION
# =====================================================================
echo ""
echo "----------------------------------------------------------"
echo "Select your primary Graphical Desktop Workspace:"
echo " [1] Hyprland    (Modern, Hardware-Accelerated Tiling Manager)"
echo " [2] KDE Plasma (Feature-Rich, Traditional, Familiar Desktop)"
echo " [3] XFCE       (Lightweight, Ultra-Stable Core Matrix)"
echo "----------------------------------------------------------"
read -p "Enter Desktop choice (1-3): " DE_CHOICE

case $DE_CHOICE in
    1)
        CORE_PKGS="$CORE_PKGS hyprland waybar kitty rofi-wayland xdg-desktop-portal-hyprland"
        ;;
    2)
        CORE_PKGS="$CORE_PKGS plasma-desktop plasma-nm power-profiles-daemon kscreen"
        ;;
    3)
        CORE_PKGS="$CORE_PKGS xfce4 xfce4-goodies"
        ;;
    *)
        echo "[WARNING] Invalid selection. Defaulting installation layout to XFCE."
        CORE_PKGS="$CORE_PKGS xfce4 xfce4-goodies"
        ;;
esac

# =====================================================================
#             ADMINISTRATIVE ACCOUNT CONFIGURATION
# =====================================================================
echo ""
echo "----------------------------------------------------------"
echo "            ADMINISTRATIVE USER ACCOUNT CREATION          "
echo "----------------------------------------------------------"
read -p "Enter new account username: " username

if [ -z "$username" ]; then
    username="eadxm_user"
    echo "[INFO] Blind path detected. Defaulting account name to: $username"
fi

echo "Enter secure authentication password for $username:"
read -s user_password
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
#             EXECUTE CHROOT PROFILE PROVISIONING USER MATRIX
# =====================================================================
echo "[INFO] Configuring user credentials and group management rules..."

# Provision the user profile with standard interactive access configurations
arch-chroot $TARGET useradd -m -G wheel -s /bin/bash "$username"
echo "$username:$user_password" | arch-chroot $TARGET chpasswd
echo "root:$user_password" | arch-chroot $TARGET chpasswd

# Uncomment the standard administrative elevation parameter inside sudoers
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' $TARGET/etc/sudoers

# ADDED FIX: Generate basic system localization parameters natively
echo "en_US.UTF-8 UTF-8" > $TARGET/etc/locale.gen
arch-chroot $TARGET locale-gen
echo "LANG=en_US.UTF-8" > $TARGET/etc/locale.conf

# ADDED FIX: Configure hardware clock to universal standard
arch-chroot $TARGET hwclock --systohc

# ADDED FIX: Apply a safe wrapper around service deployments to prevent false script aborts
echo "[INFO] Enabling hardware daemon services (Bluetooth, Networking)..."
arch-chroot $TARGET systemctl enable sddm.service || true
arch-chroot $TARGET systemctl enable NetworkManager.service || true
arch-chroot $TARGET systemctl enable bluetooth.service || true

# Configure GRUB parameters safely
echo "GRUB_DISABLE_OS_PROBER=$GRUB_OS_PROBER" >> $TARGET/etc/default/grub

echo "[INFO] Installing GRUB bootloader payload..."
arch-chroot $TARGET grub-install --target=x86_64-efi --efi-directory=$EFI_DIR --bootloader-id=ArchLinux --recheck

# If Online, map our Flatpak containers setup
if [ "$INSTALL_MODE" == "1" ]; then
    echo "[INFO] Deploying flatpak repository bindings..."
    arch-chroot $TARGET flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    
    if [ "$BROWSER_CHOICE" == "1" ]; then
        echo "[INFO] Downloading and compiling Zen Browser Container..."
        arch-chroot $TARGET flatpak install flathub app.zen_browser.zen -y
    elif [ "$BROWSER_CHOICE" == "3" ]; then
        echo "[INFO] Downloading and compiling Brave Browser Container..."
        arch-chroot $TARGET flatpak install flathub com.brave.Browser -y
    fi
fi

# Generate main GRUB configuration image matrix
arch-chroot $TARGET grub-mkconfig -o /boot/grub/grub.cfg

# Generate file system mount table entries accurately
genfstab -U $TARGET >> $TARGET/etc/fstab

echo "=========================================================="
echo "   EADXM'S ARCH COMPILED! REBOOTING IN 5 SECONDS...       "
echo "=========================================================="
sleep 5
reboot
