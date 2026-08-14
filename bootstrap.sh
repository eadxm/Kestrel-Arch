#!/bin/bash
set -e

# =====================================================================
# ⚠️ REPOSITORY CONFIGURATION ⚠️
# =====================================================================
GITHUB_REPO="eadxm/Kestrel-Arch"

clear
echo "=========================================================="
echo "          KESTREL ARCH UNIVERSAL BOOTSTRAPPER             "
echo "=========================================================="
echo "This script will deploy Kestrel Arch on a vanilla Arch Linux ISO."
echo "An active internet connection is strictly required."
echo ""

# =====================================================================
# SMART RAM GATEKEEPER & ZRAM OOM PREVENTION (For 2GB VMs)
# =====================================================================
TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
if [ -n "$TOTAL_RAM" ] && [ "$TOTAL_RAM" -lt 4096 ]; then
    echo "[SYSTEM CHECK] $TOTAL_RAM MB RAM detected. Enabling ZRAM (Compressed Swap)..."
    
    # Load the zram kernel module
    modprobe zram 2>/dev/null || true
    
    # Initialize a 1.5GB compressed RAM block
    ZRAM_DEV=$(zramctl --find --size 1536M 2>/dev/null) || true
    
    if [ -n "$ZRAM_DEV" ]; then
        mkswap "$ZRAM_DEV" >/dev/null 2>&1
        swapon "$ZRAM_DEV" -p 32767 || true
        echo "[INFO] ZRAM active on $ZRAM_DEV. Memory capacity artificially expanded!"
    else
        echo "[WARNING] Failed to initialize ZRAM. Proceeding with caution..."
    fi
fi

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
curl -sL "https://raw.githubusercontent.com/${GITHUB_REPO}/refs/heads/main/airootfs/usr/local/bin/install.sh" -o /usr/local/bin/install.sh
chmod +x /usr/local/bin/install.sh

if [ "$UI_CHOICE" = "1" ]; then
    echo "=> Initializing Graphical Environment in Live RAM..."
    
    # 2GB RAM SURVIVAL TACTIC: Push tmpfs to 90% of total RAM to fit everything
    echo "=> Maximizing RAM-disk capacity..."
    mount -o remount,size=90% /run/archiso/cowspace || true
    
    pacman-key --init >/dev/null 2>&1 || true
    pacman-key --populate archlinux >/dev/null 2>&1 || true

    # 1. Sync databases ONLY (No full system upgrade to prevent RAM suffocation)
    echo "=> Syncing package databases..."
    pacman -Sy --noconfirm || true
    
    # 2. NUCLEAR CACHE FLUSH: ONLY delete the package tarballs, NOT the sync databases!
    echo "=> Reclaiming RAM disk space..."
    rm -rf /var/cache/pacman/pkg/*
    
    # 3. Add --needed so we NEVER reinstall packages that already exist
    echo "=> Installing Wayland, Cage, and UI Dependencies..."
    pacman -S --noconfirm --needed cage wayland ttf-dejavu gparted polkit ttf-liberation noto-fonts pciutils
    
    # 4. Final nuclear flush before fetching the GUI
    echo "=> Clearing final package cache..."
    rm -rf /var/cache/pacman/pkg/*
    
    echo "=> Fetching Kestrel GUI Binary..."
    curl -sL "https://github.com/${GITHUB_REPO}/releases/latest/download/kestrel-gui" -o /usr/local/bin/kestrel-gui
    chmod +x /usr/local/bin/kestrel-gui

    echo "=> Initializing Wayland Compositor Environment..."
    # 1. Secure Runtime Directory (Mandatory for Wayland as root)
    export XDG_RUNTIME_DIR=/run/user/$(id -u)
    mkdir -p "$XDG_RUNTIME_DIR"
    chmod 0700 "$XDG_RUNTIME_DIR"
    
    # 2. Universal Wayland/Slint Fallback Variables
    export WLR_NO_HARDWARE_CURSORS=1
    export WLR_RENDERER_ALLOW_SOFTWARE=1
    export LIBGL_ALWAYS_SOFTWARE=1
    export SLINT_BACKEND=winit
    
    IS_VM=$(systemd-detect-virt -q && echo 1 || echo 0)
    HAS_NVIDIA=$(lspci | grep -iE "vga.*nvidia|3d.*nvidia" >/dev/null 2>&1 && echo 1 || echo 0)
    if [ "$IS_VM" = "1" ] || [ "$HAS_NVIDIA" = "1" ]; then
        echo "[INFO] VM or NVIDIA detected. Forcing pure software rendering (Pixman)..."
        export WLR_RENDERER=pixman
    fi
    
    echo "=> Launching Kestrel GUI..."
    cage -s -- /usr/local/bin/kestrel-gui

else
    echo "=> Launching Headless CLI Engine..."
    export NON_INTERACTIVE=0
    export INSTALL_MODE="1" 
    /usr/local/bin/install.sh
fi
