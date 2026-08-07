#!/bin/bash
set -e

# =====================================================================
# ⚠️ REPOSITORY CONFIGURATION ⚠️
# Hardcoded to pull from the official Kestrel-Arch repository
# =====================================================================
GITHUB_REPO="eadxm/Kestrel-Arch"

clear
echo "=========================================================="
echo "          KESTREL ARCH UNIVERSAL BOOTSTRAPPER             "
echo "=========================================================="
echo "This script will deploy Kestrel Arch on a vanilla Arch Linux ISO."
echo "An active internet connection is strictly required."
echo ""
echo "Select Deployment Interface:"
echo " [1] Graphical Installer (Downloads Wayland & GParted to RAM)"
echo " [2] Headless CLI Installer (Pure Terminal)"
echo "----------------------------------------------------------"

while true; do
    read -r -p "Choice (1-2): " UI_CHOICE
    if [[ "$UI_CHOICE" =~ ^[1-2]$ ]]; then break; else echo "[WARNING] Invalid choice."; fi
done

# 1. Download the backend script no matter what the user chooses
echo "=> Fetching Kestrel Backend Engine..."
mkdir -p /usr/local/bin

curl -sL "https://raw.githubusercontent.com/${GITHUB_REPO}/main/install.sh" -o /usr/local/bin/install.sh
chmod +x /usr/local/bin/install.sh

if [ "$UI_CHOICE" = "1" ]; then
    echo "=> Initializing Graphical Environment in Live RAM..."
    
    # Expand Arch ISO RAM-disk capacity to 75% to prevent out-of-memory errors
    echo "=> Expanding RAM-disk capacity..."
    mount -o remount,size=75% /run/archiso/cowspace || true
    
    # Sync Arch keys to prevent signature errors on vanilla ISOs
    pacman-key --init >/dev/null 2>&1 || true
    pacman-key --populate archlinux >/dev/null 2>&1 || true

    echo "=> Synchronizing package database to ISO build date..."
    # Extract the exact build date of the live ISO (e.g., 2024.01.01)
    ISO_DATE=$(grep BUILD_ID /etc/os-release | cut -d'=' -f2 | tr -d '"')
    # Format the date for the Arch Archive URL (e.g., 2024/01/01)
    ARCHIVE_DATE=${ISO_DATE//./\/}
    
    # Point pacman mirrors to the exact date the ISO was created
    echo "Server = https://archive.archlinux.org/repos/${ARCHIVE_DATE}/\$repo/os/\$arch" > /etc/pacman.d/mirrorlist
    
    # Sync database cleanly from the time machine
    pacman -Sy --noconfirm
    
    # Install GUI components completely safely (No overwrite flags needed!)
    pacman -S --noconfirm cage wayland ttf-dejavu gparted polkit ttf-liberation noto-fonts pciutils
    
    # Instantly free up ~140 MB of RAM
    echo "=> Clearing package cache to free memory..."
    pacman -Sc --noconfirm || true
    
    echo "=> Fetching Kestrel GUI Binary..."
    curl -sL "https://github.com/${GITHUB_REPO}/releases/latest/download/kestrel-gui" -o /usr/local/bin/kestrel-gui
    chmod +x /usr/local/bin/kestrel-gui

    echo "=> Launching Engine..."
    export XDG_RUNTIME_DIR=/run/user/$(id -u)
    export WLR_NO_HARDWARE_CURSORS=1
    export WLR_RENDERER_ALLOW_SOFTWARE=1
    
    # Auto-detect VM or NVIDIA to prevent Wayland crashes on vanilla Arch
    IS_VM=$(systemd-detect-virt -q && echo 1 || echo 0)
    HAS_NVIDIA=$(lspci | grep -iE "vga.*nvidia|3d.*nvidia" >/dev/null 2>&1 && echo 1 || echo 0)
    if [ "$IS_VM" = "1" ] || [ "$HAS_NVIDIA" = "1" ]; then
        export WLR_RENDERER=pixman
    fi
    
    # Start the Wayland compositor and hand it the Rust GUI
    cage -s -- /usr/local/bin/kestrel-gui

else
    echo "=> Launching Headless CLI Engine..."
    export NON_INTERACTIVE=0
    # For CLI on vanilla ISO, we MUST force online mode since there is no offline cache
    export INSTALL_MODE="1" 
    /usr/local/bin/install.sh
fi
