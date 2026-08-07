slint::include_modules!();

use std::process::{Command, Stdio};
use std::io::{BufRead, BufReader};
use std::thread;
use std::rc::Rc;
use slint::{ModelRc, SharedString, VecModel};

fn main() -> Result<(), slint::PlatformError> {
    let ui = InstallerWindow::new()?;
    
    // ==========================================
    // HARDWARE SCANNER: Fetch real disks via lsblk
    // ==========================================
    let output = Command::new("lsblk")
        .arg("-nd")
        .arg("-o")
        .arg("NAME,SIZE")
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

    let disks_model = Rc::new(VecModel::from(disks));
    ui.set_available_disks(ModelRc::from(disks_model.clone()));

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
                let status = Command::new("ping")
                    .arg("-c")
                    .arg("1")
                    .arg("-W")
                    .arg("2")
                    .arg("archlinux.org")
                    .status();
                
                if status.is_err() || !status.unwrap().success() {
                    needs_wifi = true;
                }
            }

            slint::invoke_from_event_loop(move || {
                if let Some(ui) = ui_handle.upgrade() {
                    if needs_wifi {
                        ui.set_active_step(2);
                    } else {
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
            let iface_output = Command::new("sh")
                .arg("-c")
                .arg("iw dev | awk '$1==\"Interface\"{print $2}' | head -n 1")
                .output();
            
            if let Ok(out) = iface_output {
                let iface = String::from_utf8_lossy(&out.stdout).trim().to_string();
                if !iface.is_empty() {
                    let _ = Command::new("iwctl").arg("station").arg(&iface).arg("scan").status();
                    thread::sleep(std::time::Duration::from_secs(2));
                    
                    let nets_output = Command::new("sh")
                        .arg("-c")
                        .arg(format!("iwctl station {} get-networks | awk 'NR>4 {{print $2}}'", iface))
                        .output();
                    
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
                            let net_model = Rc::new(VecModel::from(net_list));
                            slint::invoke_from_event_loop(move || {
                                if let Some(ui) = ui_handle.upgrade() {
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
            let iface_output = Command::new("sh")
                .arg("-c")
                .arg("iw dev | awk '$1==\"Interface\"{print $2}' | head -n 1")
                .output();
            
            if let Ok(out) = iface_output {
                let iface = String::from_utf8_lossy(&out.stdout).trim().to_string();
                if !iface.is_empty() {
                    if pass_str.is_empty() {
                        let _ = Command::new("iwctl").arg("station").arg(&iface).arg("connect").arg(&ssid_str).status();
                    } else {
                        let _ = Command::new("iwctl")
                            .arg("station")
                            .arg(&iface)
                            .arg("connect")
                            .arg(&ssid_str)
                            .arg("--passphrase")
                            .arg(&pass_str)
                            .status();
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
        Command::new("systemctl")
            .arg("reboot")
            .spawn()
            .expect("Failed to execute reboot command");
    });

    ui.global::<InstallerLogic>().on_poweroff_system(move || {
        Command::new("systemctl")
            .arg("poweroff")
            .spawn()
            .expect("Failed to execute poweroff command");
    });

    // ==========================================
    // INSTALLER LOGIC: Execute Bash Backend
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
        
        let browser_num = browser.as_str().split('.').next().unwrap_or("1").to_string();
        let perf_char = if perf.as_str().starts_with('Y') { "Y" } else { "N" };
        let de_num = selected_de.as_str().split('.').next().unwrap_or("1").to_string();
        let boot_num = selected_boot.as_str().split('.').next().unwrap_or("1").to_string();
        
        thread::spawn(move || {
            let mut child = Command::new("bash")
                .arg("/usr/local/bin/install.sh") 
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
                .stderr(Stdio::piped())
                .spawn()
                .expect("Failed to execute Kestrel bash script");

            let stdout = child.stdout.take().expect("Failed to capture stdout");
            let reader = BufReader::new(stdout);

            let mut current_progress: f32 = 0.0;
            let mut full_log = String::from("> Initiating Kestrel Arch Deployment Protocol...\n> Reading configuration matrix...\n");

            for line in reader.lines() {
                if let Ok(output) = line {
                    if output.contains("Formatting") || output.contains("partition") {
                        current_progress = 0.25;
                    } else if output.contains("pacstrap") || output.contains("Installing") {
                        current_progress = 0.60;
                    } else if output.contains("bootloader") || output.contains("grub") || output.contains("limine") {
                        current_progress = 0.85;
                    }

                    full_log.push_str("> ");
                    full_log.push_str(&output);
                    full_log.push('\n');

                    let status_text = output.clone();
                    let log_update = full_log.clone();
                    
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
                }
            }
            
            let status = child.wait().expect("Failed to wait on backend process");

            if !status.success() {
                full_log.push_str("\n[!] CRITICAL FAULT: Deployment process exited with a non-zero status code.");
            }
            let final_log = full_log.clone();

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
