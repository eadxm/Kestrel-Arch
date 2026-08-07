#!/bin/bash
set -e

clear
echo "=========================================================="
echo "          KESTREL ARCH UNIVERSAL BOOTSTRAPPER             "
echo "=========================================================="
echo "This script will deploy Kestrel Arch on a vanilla Arch Linux ISO."
echo "An active internet connection is strictly required."
echo ""

echo "Select Deployment Interface:"
echo " [1] Graphical Installer (Slint GUI & GParted on Wayland)"
echo " [2] Headless CLI Installer (Pure Terminal)"
echo "----------------------------------------------------------"
while true; do
    read -r -p "Choice (1-2): " UI_CHOICE
    if [[ "$UI_CHOICE" =~ ^[1-2]$ ]]; then break; else echo "[WARNING] Invalid choice."; fi
done

# Fetch Kestrel Backend Engine
echo "=> Fetching Kestrel Backend Engine..."
mkdir -p /usr/local/bin
curl -sL "https://raw.githubusercontent.com/eadxm/Kestrel-Arch/refs/heads/main/airootfs/usr/local/bin/install.sh" -o /usr/local/bin/install.sh
chmod +x /usr/local/bin/install.sh

if [ "$UI_CHOICE" = "1" ]; then
    echo "=> Initializing Graphical Environment in Live RAM..."
    
    # 2GB RAM SURVIVAL TACTIC: Push tmpfs to 90% of total RAM to fit GParted
    echo "=> Maximizing RAM-disk capacity..."
    mount -o remount,size=90% /run/archiso/cowspace || true
    
    pacman-key --init >/dev/null 2>&1 || true
    pacman-key --populate archlinux >/dev/null 2>&1 || true

    # The DIET UPGRADE: Upgrade system libraries safely, using wildcards to block ALL split firmware blobs
    echo "=> Upgrading base libraries safely..."
    pacman -Syu --ignore "linux,linux-firmware*,linux-api-headers,mkinitcpio" --noconfirm
    
    # Install Wayland, GParted, and fonts
    echo "=> Installing Wayland and GParted..."
    pacman -S --noconfirm cage wayland ttf-dejavu gparted polkit ttf-liberation noto-fonts pciutils
    
    # Instantly dump package cache to free memory
    echo "=> Clearing package cache to free memory..."
    pacman -Sc --noconfirm || true
    
    echo "=> Fetching Kestrel GUI Binary..."
    curl -sL "https://github.com/eadxm/Kestrel-Arch/releases/latest/download/kestrel-gui" -o /usr/local/bin/kestrel-gui
    chmod +x /usr/local/bin/kestrel-gui

    echo "=> Launching Engine..."
    export XDG_RUNTIME_DIR=/run/user/$(id -u)
    export WLR_NO_HARDWARE_CURSORS=1
    export WLR_RENDERER_ALLOW_SOFTWARE=1
    
    IS_VM=$(systemd-detect-virt -q && echo 1 || echo 0)
    HAS_NVIDIA=$(lspci | grep -iE "vga.*nvidia|3d.*nvidia" >/dev/null 2>&1 && echo 1 || echo 0)
    if [ "$IS_VM" = "1" ] || [ "$HAS_NVIDIA" = "1" ]; then
        export WLR_RENDERER=pixman
    fi
    
    cage -s -- /usr/local/bin/kestrel-gui

else
    echo "=> Launching Headless CLI Engine..."
    export NON_INTERACTIVE=0
    export INSTALL_MODE="1" 
    /usr/local/bin/install.sh
fi
