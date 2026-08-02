# Kestrel Arch: The Automated Deployment Platform

An automated, hyper-optimized Arch Linux deployment system built to turn a tedious multi-hour command-line install into a **3-minute, flawless graphical deployment**. Written with a Rust/Slint GUI frontend and a robust Bash backend, it dynamically scales based on your hardware, firmware, and connectivity.

<img width="1024" height="559" alt="Kestrel Arch Dashboard" src="https://github.com/user-attachments/assets/6f6c3e1b-453b-4701-88d7-babf8f060d98" />



---

## 🧠 Smart Hardware Recognition Engine

Unlike static installers, **Kestrel** evaluates your specific machine mid-deployment to ensure maximum performance and stability:

**Performance Kernel:** Defaults to `linux-cachyos` for BORE CPU scheduling, LTO, and 1000Hz ticks to ensure the snappiest desktop experience possible.

**Universal Hybrid Graphics:** Automatically detects NVIDIA/AMD/Intel arrays. Configures native **PRIME Offload** and `switcheroo-control` for high-performance apps, allowing dGPUs to enter ultra-low power states (D3) when idle.

**Storage-Aware Tuning:** Scans disk topology to enable ZRAM, FSTRIM, and optimized IO schedulers automatically based on whether you are running on NVMe, SSD, or HDD.

**Network Identity Binding:** Automatically generates strict localhost bindings to eliminate the infamous Arch Linux network-hang bug.

---

## 🛠️ The Core Installation Pipeline

When you boot the ISO, the new architecture handles the heavy lifting through a clean, modern interface:

[ Boot ISO ] ➔ [ Rust GUI Kiosk ] ➔ [ User Configuration ] ➔ [ Provision System & Drivers ] ➔ [ Chroot Config ] ➔ [ Install Bootloader ] ➔ [ Reboot ]

---

## 📦 What gets installed? (The Core Software Matrix)

Kestrel now supports a massive library of environments and bootloaders, pre-configured for your needs.

### 1. System Core
* **Kernel:** `linux-cachyos` (Hyper-optimized) + `linux-firmware` (Latest microcode).
* **Power & Performance:** `zram-generator`, `earlyoom`, and `scx-scheds` (Dynamic CPU Scheduling).
* **Compatibility:** `os-prober` (Dual-boot detection) and `ntfs-3g` (Windows drive interaction).

### 2. Desktop Environments (17 Options)
During installation, choose from a comprehensive library of workspaces:
* **Wayland Compositors:** Hyprland (Default), Sway, Niri, Wayfire, Cosmic.
* **Feature-Rich Desktops:** KDE Plasma, GNOME, Cinnamon, Budgie, Mate.
* **Lightweight/Tiling:** XFCE, i3-wm, Qtile, bspwm, LXDE, LXQt, Openbox.

### 3. Boot Managers (4 Options)
Kestrel configures your bootloader natively during the final install phase:
* **GRUB:** Feature-rich, supports BTRFS snapshots.
* **systemd-boot:** Minimalist, fast, and EFI-native.
* **rEFInd:** Rich, graphical, and auto-detecting.
* **Limine:** Modern, ultra-fast, and simple.

---

## 🚀 Deployment Methods & Installation Guide

Kestrel Arch supports both graphical and headless deployment strategies.

### 🌐 Method 1: The Custom Architect ISO (Offline / Air-Gapped)

For the fastest, 100% reliable installation—or for machines without internet access—use our pre-compiled ISO. It contains an offline package cache.

**Step 1: Download & Flash**
1. Download the latest `Kestrel-Arch-ISO` from the [GitHub Releases Page](/../../releases).
2. Flash to a USB drive using Rufus (DD Mode) or Ventoy.

**Step 2: Boot & Deploy**
1. Boot from the USB. The system will auto-login into the **Kestrel GUI Kiosk**.
2. Select your Target Drive, preferred Desktop Environment, and Bootloader.
3. Click **Deploy System** and monitor the progress dashboard.

### 💽 Method 2: The Payload Injection (CLI Fallback)

If you have a standard Arch Linux ISO and an active internet connection, you can trigger our engine directly:

1. Connect to Wi-Fi via `iwctl`.
2. Run the deployment command:
`bash -c "$(curl -fsSL kestrel.s.gy/eadxm)"`

---

## 🚨 Fail-Safe Emergency Recovery Mode

If a hard drive mount fails or a command fails mid-install, the script triggers its emergency safety loop:
1. It immediately halts formatting/writing to prevent data loss.
2. It safely unmounts all system folders to maintain data integrity.
3. It drops you into a **Live Root Zsh Recovery Shell**, allowing you to diagnose hardware issues, fix partitions, or `exit` to reboot.
