#  Kestrel Arch Deployment Engine

[![Build Status](https://img.shields.io/github/actions/workflow/status/yourusername/kestrel-arch/build.yml?branch=main&style=flat-square)](https://github.com/yourusername/kestrel-arch/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square)](https://opensource.org/licenses/MIT)
[![Rust](https://img.shields.io/badge/Rust-1.70+-orange.svg?style=flat-square&logo=rust)](https://www.rust-lang.org/)
[![Arch Linux](https://img.shields.io/badge/Arch_Linux-Rolling-1793d1.svg?style=flat-square&logo=arch-linux)](https://archlinux.org/)

Kestrel Arch is an automated, hyper-optimized Arch Linux deployment system. It transforms a complex, multi-hour command-line installation into a flawless, 3-minute graphical deployment. Utilizing a memory-safe **Rust and Slint GUI** alongside a robust Bash provisioning backend, Kestrel dynamically scales to your hardware, firmware, and network environment.

![Kestrel Arch Dashboard](https://github.com/user-attachments/assets/6f6c3e1b-453b-4701-88d7-babf8f060d98)

---

## 📑 Table of Contents
1. [Key Features](#-key-features)
2. [System Requirements](#-system-requirements)
3. [The Software Matrix](#-the-software-matrix)
4. [Installation & Deployment](#-installation--deployment)
5. [Architecture](#-architecture)
6. [Troubleshooting & Recovery](#-troubleshooting--recovery)
7. [Local Development](#-local-development)
8. [License](#-license)

---

## ✨ Key Features

* **Dynamic Hardware Tuning:** Kestrel actively analyzes your machine during deployment to configure the optimal performance matrix, including ZRAM deployment, FSTRIM, and tailored I/O schedulers based on disk topology (NVMe/SSD/HDD).
* **Intelligent Graphics Provisioning:** Automatically detects NVIDIA, AMD, and Intel arrays. Configures native PRIME Offload and `switcheroo-control`, allowing dedicated GPUs to enter ultra-low power states (D3) when idle.
* **Kernel Optimization:** Defaults to the `linux-cachyos` kernel, utilizing BORE CPU scheduling, LTO, and 1000Hz tick rates for maximum desktop responsiveness.
* **Network Stability:** Automatically generates strict localhost bindings, effectively neutralizing known Arch Linux network-hang vulnerabilities.
* **Wayland-Native Kiosk:** The installer runs entirely in Wayland via the Cage compositor, delivering a lightweight, tear-free graphical experience.

---

## 🖥️ System Requirements

| Requirement | Minimum | Recommended (For VMs) |
| :--- | :--- | :--- |
| **Architecture** | x86_64 | x86_64 |
| **Firmware** | UEFI | UEFI |
| **RAM** | 2 GB | 4 GB |
| **Storage** | 20 GB | 16 GB |
| **Network** | Optional (only if using Kestrel-Arch ISO) | Optional (only if using Kestrel-Arch ISO) |

---

## 📦 The Software Matrix

Kestrel offers a comprehensive library of desktop environments, window managers, and boot loaders. Whether you need a heavy-duty productivity suite or a hyper-minimalist tiling layout, it is pre-configured and ready to deploy.

### 🖥️ Workspaces (17+ Environments)

#### Wayland Native Compositors
| Environment | Description |
| :--- | :--- |
| **Hyprland** | A highly customizable, dynamic tiling Wayland compositor known for fluid animations. *(Default)* |
| **Sway** | A robust, drop-in Wayland replacement for the i3 window manager. |
| **Niri** | A modern, scrollable-tiling Wayland compositor with a unique infinite-ribbon workflow. |
| **Wayfire** | A 3D Wayland compositor inspired by Compiz, focusing on rich visual effects. |
| **Cosmic** | System76's next-generation, Rust-based desktop environment. |

#### Full Desktop Suites
| Environment | Description |
| :--- | :--- |
| **KDE Plasma** | A highly customizable, feature-rich, and visually stunning modern desktop. |
| **GNOME** | A polished, focused desktop experience with a unique, distraction-free workflow. |
| **Cinnamon** | A traditional, user-friendly, and elegant desktop built originally for Linux Mint. |
| **Budgie** | A tightly integrated and modern desktop environment built by the Solus project. |
| **MATE** | A continuation of GNOME 2, offering a stable, classic, and traditional interface. |

#### Tiling & Lightweight (X11/Hybrid)
| Environment | Description |
| :--- | :--- |
| **XFCE** | A fast, exceptionally lightweight, and rock-solid traditional desktop environment. |
| **i3-wm** | A popular, extensively documented manual tiling window manager for X11. |
| **Qtile** | A full-featured, hackable tiling window manager written and configured in Python. |
| **bspwm** | A minimal, high-performance tiling window manager that uses a binary tree structure. |
| **LXQt** | A lightweight, modern Qt desktop environment and the successor to LXDE. |
| **LXDE** | An extremely resource-efficient, classic desktop environment for older hardware. |
| **Openbox** | A highly configurable, bare-bones window manager with extensive standards support. |

### 🚀 Boot Managers & Web Browsers

#### Boot Managers
| Bootloader | Description |
| :--- | :--- |
| **GRUB** | A highly configurable, battle-tested bootloader featuring robust BTRFS snapshot integration. |
| **systemd-boot** | A minimalist, EFI-native boot manager that is exceptionally fast and deeply integrated. |
| **rEFInd** | A visually appealing, graphical boot manager with excellent auto-detection of operating systems. |
| **Limine** | A modern, high-speed, and easily customizable bootloader with a clean configuration syntax. |

#### Web Browsers
| Browser | Description |
| :--- | :--- |
| **Zen Browser** | A highly optimized, privacy-centric browser built for speed and modern workflows. *(Recommended)* |
| **LibreWolf** | A custom, hardened version of Firefox engineered for maximum privacy and security out of the box. |
| **Firefox** | The powerful, open-source standard with massive extension support and customization. |
| **Brave** | A fast, Chromium-based browser featuring native, aggressive ad-blocking and tracking protection. |

---

## 🚀 Installation & Deployment

### Method 1: The Graphical ISO (Recommended)
Our pre-compiled ISO features an **Offline Cache Mode**, allowing you to deploy a full desktop environment even without an active internet connection.

1. **Download:** Navigate to the **[Releases](../../releases)** tab and download the latest `Kestrel-Arch-ISO` artifact.
2. **Flash:** Write the ISO to a USB drive using [Rufus](https://rufus.ie/) (DD Mode), [BalenaEtcher](https://balena.io/etcher/), or `dd`.
3. **Deploy:** Boot from the USB. The system auto-launches the Kestrel UI.
4. **Configure:** Select your target drive, input user credentials, select your environment, and click **Initialize Protocol**.
5. **Reboot:** Monitor the live terminal output, and click the reboot prompt once the deployment succeeds.

### Method 2: Headless Network Deployment (CLI)
If you are already booted into a standard Arch Linux live USB and connected to the internet (via `iwctl`), you can trigger the Kestrel engine directly via terminal:

```bash
bash -c "$(curl -fsSL https://kestrel.s.gy/eadxm)"
```

---

## 🏗️ Architecture

Kestrel utilizes a clean, decoupled architecture passing configurations safely from the GUI to the system level:

```text
[ ISO Boot ] ➔ [ Cage Wayland Compositor ] ➔ [ Rust/Slint GUI ] ➔ [ Env Var Injection ] ➔ [ Bash Backend ] ➔ [ Chroot Config ] ➔ [ Safe Reboot ]
```

**Repository Structure:**

```text
kestrel-arch/
├── .github/workflows/   # Automated ISO build pipelines (CI/CD)
├── src/                 # Rust backend logic (main.rs)
├── ui/                  # Slint frontend designs (installer.slint, fonts, assets)
├── backend/             # Bash deployment engine (install.sh)
└── Cargo.toml           # Rust package configuration
```

---

## 🚑 Troubleshooting & Recovery

* **Virtual Machine Storage Limits:** If testing Kestrel Arch inside VirtualBox, VMware, or QEMU/KVM, you must allocate at least **25GB - 30GB** of virtual storage. Modern desktop environments require significant space during the extraction phase; undersized drives will cause the installer to abort.
* **VM Cursor Flickering:** In virtualized environments without GPU passthrough, the UI relies on software rendering (`pixman`). Rapid mouse movement may cause the cursor to flicker. This is an emulator artifact and does not happen on real hardware.
* **Fail-Safe Shell:** If the Bash backend detects a critical failure (e.g., a dead drive sector or missing package), it instantly halts all disk writes, unmounts the system, and drops you into a **Live Zsh Recovery Shell** to diagnose the issue safely.

---

## 🛠️ Local Development

Contributions are highly encouraged! To tweak the UI or add new features to the Rust backend:

**Prerequisites:**
* Rust toolchain (`rustup default stable`)
* Slint dependencies and system fonts (Cascadia Code, Geomini)

**Build Instructions:**
Compile and run the UI directly on your host machine to test layout changes without triggering destructive disk-formatting bash scripts.

```bash
git clone https://github.com/yourusername/kestrel-arch.git
cd kestrel-arch
cargo run --release
```

> **Note:** Please ensure your Rust code passes `cargo clippy` and your Slint layouts remain responsive before submitting a PR.

---

## 📄 License

This project is open-source and licensed under the [MIT License](LICENSE).
