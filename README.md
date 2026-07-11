<img width="1024" height="559" alt="image" src="https://github.com/user-attachments/assets/6f6c3e1b-453b-4701-88d7-babf8f060d98" />

# Kestrel Arch: an Automated Arch Architect

An automated, hyper-optimized Arch Linux deployment system built to turn a tedious multi-hour command-line install into a **3-minute, flawless deployment**. Written entirely in pure Bash, it dynamically scales based on your hardware, firmware, and connectivity.

---


## 🧠 Smart Hardware Recognition Engine

Unlike static installers, **Architect** evaluates your specific machine mid-deployment to ensure maximum performance and stability:

**Dynamic CPU Microcode:** Automatically detects Intel or AMD architecture and injects the proper silicon microcode (intel-ucode / amd-ucode) directly into the bootloader.

**Hybrid GPU Mapping:** Intelligently compiles drivers for simultaneous graphics arrays (e.g., Nvidia + Intel Optimus laptops) to prevent black-screen boot faults.

**Storage-Aware Tuning:** Scans disk topology to determine if your drive is solid-state or rotational. Automatically enables fstrim.timer for SSDs/NVMes, or applies the bfq IO Scheduler to maximize desktop smoothness on mechanical Hard Drives.

**Network Identity Binding:** Automatically generates strict localhost bindings to completely eliminate the infamous Arch Linux sudo network-hang bug.

---

## 🛠️ The Core Installation Pipeline

To understand what happens under the hood when you boot the ISO, here is how the engine processes your hardware:

[ Boot ISO ] ➔ [ Detect Firmware: UEFI vs Legacy BIOS ] ➔ [ UEFI: GPT Drive Table (1GB EFI + Root) ] OR [ BIOS: MBR Drive Table (100% Root) ] ➔ [ Provision Packages ] ➔ [ Inject Drivers ] ➔ [ Install GRUB ] ➔ [ Done ]

---

## 📦 What gets installed? (The Core Software Matrix)

The system bakes in the absolute essentials for a cutting-edge desktop experience, removing all the manual configuration work.

### 1. System Core
* **Kernel:** Stable Linux Rolling Kernel (linux) & Open-source microcode firmware updates (linux-firmware).
* **Bootloader:** Universal GRUB framework supporting modern efibootmgr logic and legacy i386-pc sectors.
* **Storage Systems:** Integrated os-prober for safe dual-boot detection and ntfs-3g to interact with Windows drives seamlessly.

### 2. Desktop Foundations
* **Display Infrastructure:** Natively bundles full xorg-server frameworks and modern Wayland compositing gates.
* **Display Manager:** Modern, themeable sddm login manager enabled automatically on boot.
* **Audio & Connectivity:** Driven completely by high-fidelity pipewire, wireplumber, and NetworkManager.

### 3. Your Desktop Workspace (Choose 1)
During installation, the engine will prompt you to choose your interface footprint:
* **Hyprland:** A modern, hardware-accelerated dynamic tiling window manager wrapped in waybar and kitty.
* **KDE Plasma:** A feature-rich, high-performance desktop framework tailored for familiarity and absolute customization.
* **XFCE:** An ultra-lightweight, blazing-fast workspace built for maximum resource stability on older hardware (perfect for older laptops).

---

## 🚀 Deployment Methods & Installation Guide

The Eadxm Arch Architect can be deployed in two ways: you can either inject the installer directly into a standard Arch Linux ISO, or use our pre-compiled Custom ISO for an offline-ready experience.

### 🌐 Method 1: The Payload Injection (Using Official Arch ISO)

If you already have a standard Arch Linux bootable USB, you do not need to download our custom ISO. You can fetch and run the engine directly from memory.

**Step 1: Connect to Wi-Fi (Skip if using Ethernet)**
The official Arch ISO boots completely offline. You must connect to the internet first:
1. Type `iwctl` and press Enter.
2. Type `station wlan0 scan`
3. Type `station wlan0 get-networks`
4. Type `station wlan0 connect "YOUR_WIFI_NAME"`
5. Type `exit`

**Step 2: Deploy the Engine**
Now that you are online, run the following command to download and launch the installer directly from memory:
`curl -sL kestrel.s.gy/eadxm | bash`

### 💽 Method 2: The Custom Architect ISO (Offline / Air-Gapped)

If you are deploying to a machine without an internet connection, or you want the absolute fastest installation possible, use our pre-compiled Custom ISO.

**Step 1: Download & Flash**
1. Head over to the [GitHub Releases Page](/../../releases) and grab the latest compiled Eadxm-Arch-Architect-ISO.
2. Flash the ISO to a USB drive using `dd` on Linux, or Rufus (choose DD Mode) on Windows.

**Step 2: Boot the Target Hardware**
1. Plug the USB into your target machine and mash your motherboard's boot-menu key (usually F12, F11, F2 or Del).
2. Select your USB drive. The live Arch image will load and automatically launch the Arch Architect interface menu.

---

## 🚨 Fail-Safe Emergency Recovery Mode

If a hard drive mount drops out, a partition alignment faults, or a script command fails mid-install, the script will instantly trigger its emergency safety loop:
1. It immediately halts formatting or writing to prevent corruption.
2. It completely unmounts all system folders safely to lock down data integrity.
3. It hands you a live Root Zsh Recovery Shell on-screen so you can diagnose the system, fix lines, or type `exit` to cleanly reboot.
