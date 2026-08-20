slint::include_modules!();

use std::process::{Command, Stdio};
use std::io::{BufRead, BufReader};
use std::thread;
use std::rc::Rc;
use std::time::{Instant, Duration};
use slint::{ModelRc, SharedString, VecModel};

// Helper function to format raw bytes into human-readable strings for the UI table
fn format_size(bytes: u64) -> String {
    let kb = 1024.0;
    let mb = kb * 1024.0;
    let gb = mb * 1024.0;
    let b = bytes as f64;
    
    if b >= gb { format!("{:.1}G", b / gb) }
    else if b >= mb { format!("{:.1}M", b / mb) }
    else if b >= kb { format!("{:.1}K", b / kb) }
    else { format!("{}B", bytes) }
}

// Reusable function to scan partitions and calculate UI layout percentages
fn scan_partitions(disk_path: &str) -> (Vec<PartitionData>, Vec<SharedString>) {
    let mut partitions = Vec::new();
    let mut available_dropdown = Vec::new();

    // 1. Get the TOTAL disk size in bytes to calculate the visualizer bar percentages
    let disk_output = Command::new("lsblk").arg("-b").arg("-n").arg("-d").arg("-o").arg("SIZE").arg(disk_path).output();
    let total_bytes: f64 = if let Ok(out) = disk_output {
        String::from_utf8_lossy(&out.stdout).trim().parse().unwrap_or(1.0)
    } else { 1.0 };

    // 2. Get all partitions with exact byte sizes
    let output = Command::new("lsblk")
        .arg("-P").arg("-b").arg("-o").arg("NAME,FSTYPE,LABEL,MOUNTPOINT,SIZE")
        .arg(disk_path)
        .output();

    if let Ok(out) = output {
        let stdout = String::from_utf8_lossy(&out.stdout);
        
        let colors = [
            slint::Color::from_rgb_u8(239, 68, 68),  // Red
            slint::Color::from_rgb_u8(245, 158, 11), // Orange
            slint::Color::from_rgb_u8(16, 185, 129), // Green
            slint::Color::from_rgb_u8(59, 130, 246), // Blue
            slint::Color::from_rgb_u8(168, 85, 247), // Purple
        ];
        let mut color_idx = 0;

        for line in stdout.lines() {
            let get_val = |key: &str| -> String {
                if let Some(start) = line.find(&format!("{}=\"", key)) {
                    let content_start = start + key.len() + 2;
                    if let Some(end) = line[content_start..].find('"') {
                        return line[content_start..content_start + end].to_string();
                    }
                }
                String::new()
            };

            let name = get_val("NAME");
            let base_disk = disk_path.replace("/dev/", "");
            
            // Skip the main drive itself, only capture the sub-partitions
            if !name.is_empty() && name != base_disk {
                let fs = get_val("FSTYPE");
                let raw_size: u64 = get_val("SIZE").parse().unwrap_or(0);
                
                // Calculate percentage of the visualizer bar it should take up
                let stretch_val = (raw_size as f64 / total_bytes) as f32;
                
                let part_path = format!("/dev/{}", name);

                let part = PartitionData {
                    name: part_path.clone().into(),
                    fstype: if fs.is_empty() { "Unformatted".into() } else { fs.into() },
                    label: get_val("LABEL").into(),
                    mountpoint: get_val("MOUNTPOINT").into(),
                    size: format_size(raw_size).into(),
                    color_hex: colors[color_idx % colors.len()],
                    stretch: stretch_val,
                };
                
                partitions.push(part);
                available_dropdown.push(part_path.into());
                color_idx += 1;
            }
        }
    }
    
    // Safety fallback: if completely empty/unallocated, show one massive gray block
    if partitions.is_empty() {
        partitions.push(PartitionData {
            name: "Unallocated Space".into(),
            fstype: "None".into(),
            label: "".into(),
            mountpoint: "".into(),
            size: format_size(total_bytes as u64).into(),
            color_hex: slint::Color::from_rgb_u8(75, 85, 99), // Gray
            stretch: 1.0,
        });
    }

    (partitions, available_dropdown)
}

fn main() -> Result<(), slint::PlatformError> {
    let ui = InstallerWindow::new()?;
    
    // ==========================================
    // INITIAL SYSTEM CHECKS (Ethernet, Offline, UEFI)
    // ==========================================
    // Check if the offline installer package cache exists
    let is_offline = std::path::Path::new("/opt/offline_cache").exists();
    ui.set_is_offline_cached(is_offline);

    // DYNAMIC UI FIX 1: Check for UEFI firmware and pass the boolean to Slint
    let is_efi = std::path::Path::new("/sys/firmware/efi").exists();
    ui.set_is_efi_system(is_efi);

    // DYNAMIC UI FIX 2: Change Falkon text based on offline status
    let falkon_text = if is_offline {
        SharedString::from("1. Falkon (Offline Default)")
    } else {
        SharedString::from("5. Falkon (Recommended for KDE/Arch)")
    };
    ui.set_falkon_label(falkon_text);

    // Initial check for hardwired ethernet (If this succeeds, we skip Wi-Fi setup)
    if let Ok(status) = Command::new("ping").arg("-c").arg("1").arg("-W").arg("2").arg("archlinux.org").status() {
        if status.success() {
            ui.set_has_ethernet(true);
        }
    }

    // ==========================================
    // HARDWARE SCANNER: Fetch real disks via lsblk
    // ==========================================
    let output = Command::new("lsblk")
        .arg("-nd").arg("-o").arg("NAME,SIZE")
        .output()
        .expect("Failed to execute lsblk");

    let mut disks: Vec<SharedString> = Vec::new();
    if output.status.success() {
        let stdout = String::from_utf8_lossy(&output.stdout);
        for line in stdout.lines() {
            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() >= 2 {
                let name = parts[0];
                let size = parts[1];
                if name.starts_with("sd") || name.starts_with("nvme") || name.starts_with("vd") {
                    let display_str = format!("/dev/{} - {}", name, size);
                    disks.push(display_str.into());
                }
            }
        }
    }

    if disks.is_empty() {
        disks.push("No drives found!".into());
    }

    // Load initial partitions for the first disk instantly
    if let Some(first_disk) = disks.first() {
        let pure = first_disk.as_str().split_whitespace().next().unwrap_or("");
        let (parts, avail) = scan_partitions(pure);
        ui.global::<InstallerLogic>().set_current_partitions(ModelRc::from(Rc::new(VecModel::from(parts))));
        ui.set_available_partitions(ModelRc::from(Rc::new(VecModel::from(avail))));
    }

    let disks_model = Rc::new(VecModel::from(disks));
    ui.set_available_disks(ModelRc::from(disks_model.clone()));

    // ==========================================
    // UI CALLBACK: Fetch Partitions Dynamically
    // ==========================================
    let ui_handle_fetch = ui.as_weak();
    ui.global::<InstallerLogic>().on_fetch_partitions(move |disk| {
        let pure_disk_path = disk.as_str().split_whitespace().next().unwrap_or("").to_string();
        let (parts, avail) = scan_partitions(&pure_disk_path);
        
        if let Some(ui) = ui_handle_fetch.upgrade() {
            ui.global::<InstallerLogic>().set_current_partitions(ModelRc::from(Rc::new(VecModel::from(parts))));
            ui.set_available_partitions(ModelRc::from(Rc::new(VecModel::from(avail))));
        }
    });

    // ==========================================
    // NETWORK LOGIC: Evaluate Online vs Offline
    // ==========================================
    let ui_handle_net = ui.as_weak();
    ui.global::<InstallerLogic>().on_check_network_and_proceed(move |mode| {
        let ui_handle = ui_handle_net.clone();
        let mode_str = mode.to_string();

        thread::spawn(move || {
            let is_online = mode_str.contains("Online");
            let mut needs_wifi = false;
            
            if is_online {
                let status = Command::new("ping").arg("-c").arg("1").arg("-W").arg("2").arg("archlinux.org").status();
                if status.is_err() || !status.unwrap().success() {
                    needs_wifi = true;
                }
            }

            slint::invoke_from_event_loop(move || {
                if let Some(ui) = ui_handle.upgrade() {
                    if needs_wifi {
                        ui.set_has_ethernet(false);
                        ui.set_active_step(2);
                    } else {
                        ui.set_has_ethernet(true);
                        ui.set_active_step(3);
                    }
                }
            }).unwrap();
        });
    });

    // ==========================================
    // NETWORK LOGIC: Wi-Fi Rescan & Connect
    // ==========================================
    let ui_handle_wifi = ui.as_weak();
    ui.global::<InstallerLogic>().on_rescan_wifi(move || {
        let ui_handle = ui_handle_wifi.clone();
        thread::spawn(move || {
            let iface_output = Command::new("sh").arg("-c").arg("iw dev | awk '$1==\"Interface\"{print $2}' | head -n 1").output();
            if let Ok(out) = iface_output {
                let iface = String::from_utf8_lossy(&out.stdout).trim().to_string();
                if !iface.is_empty() {
                    let _ = Command::new("iwctl").arg("station").arg(&iface).arg("scan").status();
                    thread::sleep(std::time::Duration::from_secs(2));
                    
                    let nets_output = Command::new("sh").arg("-c").arg(format!("iwctl station {} get-networks | awk 'NR>4 {{print $2}}'", iface)).output();
                    if let Ok(net_out) = nets_output {
                        let stdout = String::from_utf8_lossy(&net_out.stdout);
                        let mut net_list: Vec<SharedString> = Vec::new();
                        for net in stdout.lines() {
                            let clean_net = net.trim();
                            if !clean_net.is_empty() {
                                net_list.push(clean_net.into());
                            }
                        }
                        if !net_list.is_empty() {
                            slint::invoke_from_event_loop(move || {
                                if let Some(ui) = ui_handle.upgrade() {
                                    let net_model = Rc::new(VecModel::from(net_list));
                                    ui.set_available_networks(ModelRc::from(net_model.clone()));
                                }
                            }).unwrap();
                        }
                    }
                }
            }
        });
    });

    let ui_handle_connect = ui.as_weak();
    ui.global::<InstallerLogic>().on_connect_wifi(move |ssid, password| {
        let ui_handle = ui_handle_connect.clone();
        let ssid_str = ssid.to_string();
        let pass_str = password.to_string();

        thread::spawn(move || {
            let iface_output = Command::new("sh").arg("-c").arg("iw dev | awk '$1==\"Interface\"{print $2}' | head -n 1").output();
            if let Ok(out) = iface_output {
                let iface = String::from_utf8_lossy(&out.stdout).trim().to_string();
                if !iface.is_empty() {
                    if pass_str.is_empty() {
                        let _ = Command::new("iwctl").arg("station").arg(&iface).arg("connect").arg(&ssid_str).status();
                    } else {
                        let _ = Command::new("iwctl").arg("station").arg(&iface).arg("connect").arg(&ssid_str).arg("--passphrase").arg(&pass_str).status();
                    }
                    thread::sleep(std::time::Duration::from_secs(4));
                }
            }

            slint::invoke_from_event_loop(move || {
                if let Some(ui) = ui_handle.upgrade() {
                    ui.set_active_step(3);
                }
            }).unwrap();
        });
    });

    // ==========================================
    // SYSTEM LOGIC: Power Management
    // ==========================================
    ui.global::<InstallerLogic>().on_reboot_system(move || {
        let _ = Command::new("systemctl").arg("reboot").spawn();
    });

    ui.global::<InstallerLogic>().on_poweroff_system(move || {
        let _ = Command::new("systemctl").arg("poweroff").spawn();
    });

    // ==========================================
    // PARTITION MANAGER (Non-Blocking GParted)
    // ==========================================
    let ui_handle_gparted = ui.as_weak();
    ui.global::<InstallerLogic>().on_launch_gparted(move |disk| {
        let ui_handle = ui_handle_gparted.clone();
        let pure_disk_path = disk.as_str().split_whitespace().next().unwrap_or("").to_string();
        
        // Spawn in a separate thread so it DOES NOT freeze the GUI!
        thread::spawn(move || {
            // 1. Launch GParted GUI and wait for it to close
            let _ = Command::new("gparted").arg(&pure_disk_path).status();

            // 2. Rescan the new layout mapped by the user
            let (parts, avail) = scan_partitions(&pure_disk_path);

            // 3. Update the GUI dynamically
            slint::invoke_from_event_loop(move || {
                if let Some(ui) = ui_handle.upgrade() {
                    ui.global::<InstallerLogic>().set_current_partitions(ModelRc::from(Rc::new(VecModel::from(parts))));
                    ui.set_available_partitions(ModelRc::from(Rc::new(VecModel::from(avail))));
                }
            }).unwrap();
        });
    });

    // ==========================================
    // INSTALLER LOGIC: Execute Bash Backend (Crash Capture)
    // ==========================================
    let ui_handle = ui.as_weak();
    
    ui.global::<InstallerLogic>().on_start_install(move |
        target_disk, install_mode, part_strategy, 
        filesystem, replace_path,
        gui_root_part, gui_efi_part, 
        hostname, username, password, root_password, 
        browser, perf, selected_de, selected_boot
    | {
        let ui_handle = ui_handle.clone();
        
        let pure_disk_path = target_disk.as_str().split_whitespace().next().unwrap_or("").to_string();
        let mode_num = install_mode.as_str().split('.').next().unwrap_or("2").to_string();
        let part_num = part_strategy.as_str().split('.').next().unwrap_or("1").to_string();
        
        let fs_str = filesystem.as_str().to_string();
        let replace_str = replace_path.as_str().to_string();
        let root_part_str = gui_root_part.as_str().to_string(); 
        let efi_part_str = gui_efi_part.as_str().to_string();   
        
        let host_str = hostname.as_str().to_string();
        let user_str = username.as_str().to_string();
        let pass_str = password.as_str().to_string();
        let root_pass_str = root_password.as_str().to_string();
        
        let mut browser_num = browser.as_str().split('.').next().unwrap_or("1").to_string();
        let perf_char = if perf.as_str().starts_with('Y') { "Y" } else { "N" };
        let de_num = selected_de.as_str().split('.').next().unwrap_or("1").to_string();
        let boot_num = selected_boot.as_str().split('.').next().unwrap_or("1").to_string();

        // ==============================================================
        // FAILSAFE OVERRIDE: Prevent offline parsing crashes
        // If the user is offline, forcibly lock the browser index to "5".
        // This ensures the bash script installs the cached Falkon 
        // instead of trying to reach the internet for Zen Browser.
        // ==============================================================
        if mode_num == "2" {
            browser_num = "5".to_string();
        }
        
        thread::spawn(move || {
            let mut child = Command::new("bash")
                .arg("-c")
                .arg("/usr/local/bin/install.sh 2>&1")
                .env("TARGET_DISK", &pure_disk_path)
                .env("INSTALL_MODE", &mode_num)
                .env("PARTITION_STRATEGY", &part_num)
                .env("GUI_FILESYSTEM", &fs_str)
                .env("GUI_REPLACE_PART", &replace_str)
                .env("GUI_ROOT_PART", &root_part_str) 
                .env("GUI_EFI_PART", &efi_part_str)   
                .env("GUI_HOSTNAME", &host_str)
                .env("GUI_USERNAME", &user_str)
                .env("GUI_PASSWORD", &pass_str)
                .env("GUI_ROOT_PASSWORD", &root_pass_str)
                .env("BROWSER_CHOICE", &browser_num)
                .env("PERF_CHOICE", &perf_char)
                .env("DE_CHOICE", &de_num)
                .env("BOOT_CHOICE", &boot_num)
                .env("NON_INTERACTIVE", "1") 
                .stdout(Stdio::piped())
                .spawn()
                .expect("Failed to execute Kestrel bash script");

            let stdout = child.stdout.take().expect("Failed to capture stdout");
            let reader = BufReader::new(stdout);

            let mut current_progress: f32 = 0.0;
            
            // 60FPS THROTTLE: Use a vector to manage the scrollback buffer
            let mut log_lines: Vec<String> = vec![
                "> Initiating Kestrel Arch Deployment Protocol...".to_string(),
                "> Reading configuration matrix...".to_string(),
            ];

            let mut last_ui_update = Instant::now();
            let update_interval = Duration::from_millis(16); // 16ms = ~60 FPS

            for line in reader.lines() {
                if let Ok(output) = line {
                    // Update progress metrics
                    if output.contains("Formatting") || output.contains("partition") {
                        current_progress = 0.25;
                    } else if output.contains("pacstrap") || output.contains("Installing") {
                        current_progress = 0.60;
                    } else if output.contains("bootloader") || output.contains("grub") || output.contains("limine") {
                        current_progress = 0.85;
                    }

                    // Append the new line
                    log_lines.push(format!("> {}", output));

                    // AGGRESSIVE CAP: Keep scrollback to the last 100 lines for ultra-fast layout rendering
                    if log_lines.len() > 100 {
                        log_lines.remove(0);
                    }

                    // THROTTLE: Fire updates exactly at 60Hz
                    if last_ui_update.elapsed() >= update_interval {
                        let status_text = output.clone();
                        let log_update = log_lines.join("\n");
                        
                        slint::invoke_from_event_loop({
                            let ui_handle = ui_handle.clone();
                            move || {
                                if let Some(ui) = ui_handle.upgrade() {
                                    ui.global::<InstallerLogic>().set_status_text(status_text.into());
                                    ui.global::<InstallerLogic>().set_progress(current_progress);
                                    ui.global::<InstallerLogic>().set_console_log(log_update.into());
                                }
                            }
                        }).unwrap();

                        last_ui_update = Instant::now();
                    }
                }
            }
            
            let status = child.wait().expect("Failed to wait on backend process");

            if !status.success() {
                log_lines.push("\n[!] CRITICAL FAULT: Deployment process exited with a non-zero status code. Read logs above for details.".to_string());
            }
            
            // Final sync after the process exits
            let final_log = log_lines.join("\n");

            slint::invoke_from_event_loop({
                let ui_handle = ui_handle.clone();
                move || {
                    if let Some(ui) = ui_handle.upgrade() {
                        if status.success() {
                            ui.global::<InstallerLogic>().set_progress(1.0);
                            ui.set_active_step(99);
                        } else {
                            ui.global::<InstallerLogic>().set_status_text("Installation failed! Check console output.".into());
                            ui.global::<InstallerLogic>().set_console_log(final_log.into());
                        }
                    }
                }
            }).unwrap();
        });
    });

    ui.run()
}
