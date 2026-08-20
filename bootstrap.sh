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

# Fetch Kestrel Backend Engine (Removed -s to show progress)
echo "=> Fetching Kestrel Backend Engine..."
mkdir -p /usr/local/bin
curl -fL -# "https://raw.githubusercontent.com/${GITHUB_REPO}/refs/heads/main/airootfs/usr/local/bin/install.sh" -o /usr/local/bin/install.sh
sync
chmod +x /usr/local/bin/install.sh

if [ "$UI_CHOICE" = "1" ]; then
    echo "=> Initializing Graphical Environment in Live RAM..."
    
    # 2GB RAM SURVIVAL TACTIC: Push tmpfs to 4GB ceiling (relies on ZRAM to fit)
    echo "=> Maximizing RAM-disk capacity..."
    mount -o remount,size=4G /run/archiso/cowspace 2>/dev/null || true
    
    pacman-key --init >/dev/null 2>&1 || true
    pacman-key --populate archlinux >/dev/null 2>&1 || true

    # 1. THE MINIMAL FULL UPGRADE
    echo "=> Performing minimal core system upgrade..."
    pacman -Syu --overwrite "*" --ignore "linux,linux-firmware*,intel-ucode,amd-ucode,linux-api-headers,mkinitcpio,sof-firmware,open-vm-tools,virtualbox-guest-utils-nox,vim*,zsh,openvpn,openconnect,man-db,man-pages,nmap,tcpdump,python*,perl*,lvm2,mdadm,nftables,iptables,openssh,partclone,sqlite,cloud-init,hyperv,bolt,broadcom-wl,bcachefs-tools,libtorrent-rasterbar,screen,sg3_utils,tpm2-tools,archinstall,clonezilla" --noconfirm || true
    
    # 2. INSTANT NUCLEAR CACHE FLUSH (Crucial for 2GB VMs)
    echo "=> Reclaiming RAM disk space..."
    rm -rf /var/cache/pacman/pkg/*
    
    # 3. Install core GUI dependencies.
    # SWAPPED noto-fonts for ttf-liberation to save >100MB of RAM!
    echo "=> Installing Wayland, Cage, and UI Dependencies..."
    pacman -S --noconfirm --needed --overwrite "*" cage wayland gparted polkit ttf-liberation pciutils
    
    # 4. Final nuclear flush before fetching the GUI
    echo "=> Clearing final package cache & sync databases..."
    rm -rf /var/cache/pacman/pkg/*
    rm -rf /var/lib/pacman/sync/*
    
    echo "=> Fetching Kestrel GUI Binary..."
    # FIX: Destroy any locked/ghost binaries from previous cancelled runs!
    rm -f /usr/local/bin/kestrel-gui
    
    # -C -               : Automatically resume broken downloads exactly where they stopped
    # --retry 5          : Try 5 times instead of 3
    # --retry-all-errors : Force retry on connection resets and timeouts
    curl -fL -# --retry 5 --retry-all-errors --retry-delay 3 -C - "https://github.com/${GITHUB_REPO}/releases/download/latest-gui/kestrel-gui" -o /usr/local/bin/kestrel-gui
    sync
    chmod +x /usr/local/bin/kestrel-gui

    echo "=> Initializing Wayland Compositor Environment..."
    export XDG_RUNTIME_DIR=/run/user/$(id -u)
    mkdir -p "$XDG_RUNTIME_DIR"
    chmod 0700 "$XDG_RUNTIME_DIR"
    
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
