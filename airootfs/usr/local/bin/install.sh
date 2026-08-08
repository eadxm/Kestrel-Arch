import { ComboBox, ProgressIndicator, VerticalBox, HorizontalBox, LineEdit, CheckBox, ScrollView, TextEdit } from "std-widgets.slint";

// ==========================================
// FONT EMBEDDING
// ==========================================
import "./fonts/Geomini.ttf";
import "./fonts/CascadiaCode.ttf";

// Struct to hold partition data sent from Rust
export struct PartitionData {
    name: string,
    fstype: string,
    label: string,
    mountpoint: string,
    size: string,
    color_hex: color,
}

export global InstallerLogic {
    // 15 parameters to match main.rs explicitly
    callback start_install(string, string, string, string, string, string, string, string, string, string, string, string, string, string, string);
    callback poweroff_system();
    callback reboot_system();
    
    callback check_network_and_proceed(string); 
    callback rescan_wifi();
    callback connect_wifi(string, string); 
    
    // GParted Callback & Data binding
    callback launch_gparted(string);
    in-out property <[PartitionData]> current_partitions;
    
    in property <float> progress: 0.0;
    in property <string> status_text: "Ready to deploy.";
    in property <string> console_log: "> System pre-flight checks passed.\n> Standing by for deployment protocol...\n";
}

// ==========================================
// FLUID BUTTON COMPONENT
// ==========================================
component GlowingButton inherits Rectangle {
    in property <string> text;
    in property <bool> primary: false;
    callback clicked();

    height: 45px;
    width: 200px;
    border-radius: 6px;
    
    background: primary ? @linear-gradient(90deg, #14B8A6 0%, #06B6D4 100%) : transparent;
    border-width: primary ? 0px : 1px;
    border-color: primary ? transparent : (touch.has-hover ? #06B6D4 : #374151);
    animate border-color { duration: 100ms; easing: ease-in-out; }

    Text {
        text: root.text;
        color: primary ? #000000 : (touch.has-hover ? #A5F3FC : #E5E7EB);
        font-size: 14px;
        font-weight: 600;
        horizontal-alignment: center;
        vertical-alignment: center;
        animate color { duration: 100ms; easing: ease-in-out; }
    }
    
    Rectangle {
        width: 100%;
        height: 100%;
        border-radius: parent.border-radius;
        background: primary ? #000000 : #A5F3FC;
        opacity: touch.pressed ? 0.25 : (touch.has-hover ? 0.08 : 0.0);
        animate opacity { duration: 100ms; easing: ease-in-out; }
    }
    
    touch := TouchArea {
        clicked => { root.clicked(); }
        mouse-cursor: pointer;
    }
}

// ==========================================
// CUSTOM RADIO OPTION COMPONENT
// ==========================================
component RadioOption inherits Rectangle {
    in property <string> title;
    in property <string> description;
    in property <bool> active: false;
    callback clicked();

    border-radius: 8px;
    border-width: 1px;
    border-color: active ? #06B6D4 : (touch.has-hover ? #4B5563 : #1F2937);
    background: active ? #06B6D410 : (touch.has-hover ? #1F293740 : transparent);
    
    animate border-color { duration: 150ms; }
    animate background { duration: 150ms; }

    HorizontalBox {
        padding: 12px;
        spacing: 15px;
        alignment: start;

        Rectangle {
            width: 20px;
            height: 20px;
            border-radius: 10px;
            border-width: 2px;
            border-color: active ? #06B6D4 : #6B7280;
            
            Rectangle {
                width: 10px;
                height: 10px;
                border-radius: 5px;
                background: #06B6D4;
                opacity: active ? 1.0 : 0.0;
                x: (parent.width - self.width) / 2;
                y: (parent.height - self.height) / 2;
                animate opacity { duration: 150ms; }
            }
        }

        VerticalBox {
            alignment: center;
            spacing: 2px;
            Text { text: root.title; color: active ? #A5F3FC : #E5E7EB; font-size: 14px; font-weight: 700; }
            Text { text: root.description; color: active ? #9CA3AF : #6B7280; font-size: 12px; }
        }
    }

    touch := TouchArea {
        clicked => { root.clicked(); }
        mouse-cursor: pointer;
    }
}

// ==========================================
// PARTITION VISUALIZER COMPONENT
// ==========================================
component PartitionVisualizer inherits VerticalBox {
    in property <string> disk_name;
    spacing: 6px;

    Text { text: "Partition layout context for " + root.disk_name; color: #D1D5DB; font-size: 11px; font-weight: 600; }

    Rectangle {
        width: 100%; height: 22px; border-radius: 4px; clip: true; background: #1F2937;
        HorizontalLayout {
            Rectangle { width: 25%; background: #EF4444; }
            Rectangle { width: 75%; background: #06B6D4; }
        }
    }
    
    HorizontalBox {
        spacing: 15px;
        HorizontalBox { spacing: 4px; Rectangle { width: 8px; height: 8px; background: #EF4444; border-radius: 2px; } Text { text: "/dev/sda1 (EFI - 512M)"; color: #9CA3AF; font-size: 10px; } }
        HorizontalBox { spacing: 4px; Rectangle { width: 8px; height: 8px; background: #06B6D4; border-radius: 2px; } Text { text: "/dev/sda2 (Root - Target)"; color: #9CA3AF; font-size: 10px; } }
    }
}

export component InstallerWindow inherits Window {
    title: "Kestrel Arch Deployment Engine";
    
    preferred-width: 1024px;
    preferred-height: 768px;
    background: #020617; 
    
    default-font-family: "Geomini, Segoe UI, Roboto, sans-serif";

    in-out property <int> active_step: 0;
    
    in-out property <string> error_message: "";
    in-out property <bool> show_error_popup: false;
    
    property <string> selected_mode: "Choose mode of installation";
    
    // List-based Network selection properties
    in property <[string]> available_networks: ["Home-WiFi-5G", "Office-Guest", "Kestrel-Secure"];
    property <string> selected_network: "";
    property <string> wifi_password: "";
    
    in property <[string]> available_disks: ["Scanning hardware..."];
    property <string> selected_disk: root.available_disks[0];
    property <string> selected_part: "1. WIPE (Erase Entire Disk)";
    
    property <string> target_filesystem: "ext4";
    property <string> replace_partition_path: "";
    
    // Specific GUI Mount Point variables
    property <string> gui_root_part: "/dev/sda2"; // Bound to whatever the user selects in the table
    property <string> gui_efi_part: "/dev/sda1";  // Bound to whatever the user selects in the table
    
    property <string> in_hostname: "";
    property <string> in_username: "";
    property <string> in_password: "";
    property <string> in_root_password: "";
    
    property <string> selected_browser: "1. Falkon Browser (Recommended)";
    property <bool> perf_enabled: true;
    property <string> selected_de: "Choose your environment";
    property <string> selected_boot: "1. GRUB";

    property <bool> show_console: false;

    Rectangle {
        width: 880px;
        height: 640px;
        x: (parent.width - self.width) / 2;
        y: (parent.height - self.height) / 2;
        
        background: #040D14; 
        border-radius: 20px;
        border-width: 1px;
        border-color: #06B6D4; 
        drop-shadow-color: #06B6D430; 
        drop-shadow-blur: 25px;

        VerticalBox {
            padding: 30px;
            
            HorizontalBox {
                alignment: start;
                height: 32px;
                spacing: 15px;
                
                Image { source: @image-url("logo.png"); width: 32px; height: 32px; image-fit: contain; }
                Text { text: "KESTREL ARCH"; color: #E5E7EB; font-size: 14px; font-weight: 700; letter-spacing: 2px; vertical-alignment: center; }
            }

            Rectangle { height: 10px; } 

            VerticalBox {
                alignment: center;

                // =========================================================
                // STEP 0: Landing Page
                // =========================================================
                if (root.active_step == 0) : VerticalBox {
                    alignment: center; spacing: 25px;
                    VerticalBox {
                        spacing: 5px;
                        Text { text: "Kestrel Arch"; font-size: 56px; font-weight: 800; color: #A5F3FC; horizontal-alignment: center; letter-spacing: -1px; }
                        Text { text: "Installer"; font-size: 56px; font-weight: 800; color: #A5F3FC; horizontal-alignment: center; letter-spacing: -1px; }
                    }
                    Text { text: "Efficient. Robust. Custom configurations. Built to scale your infrastructure, every time."; font-size: 13px; color: #9CA3AF; horizontal-alignment: center; }
                    HorizontalBox { alignment: center; spacing: 20px; GlowingButton { text: "Begin Installation"; primary: true; clicked => { root.active_step = 1; } } }
                }

                // =========================================================
                // STEP 1: Installation Mode ONLY
                // =========================================================
                if (root.active_step == 1) : VerticalBox {
                    alignment: center; spacing: 12px; padding-left: 60px; padding-right: 60px;
                    Text { text: "Deployment Mode"; font-size: 22px; font-weight: 700; color: #A5F3FC; horizontal-alignment: center; }
                    Rectangle { height: 10px; } 

                    VerticalBox {
                        spacing: 6px;
                        Text { text: "Select Installation Mode:"; font-size: 13px; font-weight: 600; color: #D1D5DB; }
                        ComboBox { 
                            model: ["Choose mode of installation", "1. Online (Download Latest)", "2. Offline (Fast, Local Cache)"]; 
                            current-value: root.selected_mode; 
                            selected(val) => { root.selected_mode = val; } 
                            height: 38px; 
                        }
                        Text { text: "Online mode requires an active internet connection. Offline is air-gapped."; color: #6B7280; font-size: 12px; }
                    }
                    
                    HorizontalBox {
                        alignment: center; spacing: 15px; padding-top: 20px;
                        GlowingButton { text: "Back"; primary: false; clicked => { root.active_step = 0; } }
                        GlowingButton { 
                            text: "Next Step"; 
                            primary: true; 
                            clicked => { 
                                if (root.selected_mode == "Choose mode of installation") {
                                    root.error_message = "Please select an Installation Mode before proceeding.";
                                    root.show_error_popup = true;
                                } else {
                                    InstallerLogic.check_network_and_proceed(root.selected_mode);
                                }
                            } 
                        }
                    }
                }

                // =========================================================
                // STEP 2: Dedicated Network Window (List Selection Layout)
                // =========================================================
                if (root.active_step == 2) : VerticalBox {
                    alignment: center; spacing: 12px; padding-left: 40px; padding-right: 40px;
                    Text { text: "Connect to Internet"; font-size: 22px; font-weight: 700; color: #F59E0B; horizontal-alignment: center; }
                    Text { text: "Select your Wi-Fi network from the list below to proceed with Online installation."; color: #9CA3AF; font-size: 12px; horizontal-alignment: center; }
                    Rectangle { height: 5px; } 

                    Rectangle {
                        height: 160px; width: 100%; border-radius: 8px; border-width: 1px; border-color: #1F2937; background: #020617;
                        ScrollView {
                            width: 100%; height: 100%;
                            VerticalBox {
                                padding: 8px; spacing: 4px;
                                
                                for net in root.available_networks : Rectangle {
                                    height: 35px; border-radius: 4px;
                                    background: root.selected_network == net ? #06B6D420 : (net_touch.has-hover ? #1F2937 : transparent);
                                    border-width: root.selected_network == net ? 1px : 0px;
                                    border-color: #06B6D4;
                                    
                                    HorizontalBox {
                                        padding-left: 12px; padding-right: 12px; alignment: space-between;
                                        Text { text: net; color: root.selected_network == net ? #A5F3FC : #D1D5DB; font-size: 13px; font-weight: 600; vertical-alignment: center; }
                                        Text { text: root.selected_network == net ? "Connected / Selected" : ""; color: #06B6D4; font-size: 11px; vertical-alignment: center; }
                                    }
                                    net_touch := TouchArea {
                                        clicked => { root.selected_network = net; }
                                    }
                                }
                            }
                        }
                    }

                    VerticalBox {
                        spacing: 4px;
                        Text { text: "Wi-Fi Password (leave blank if open):"; font-size: 12px; font-weight: 600; color: #D1D5DB; }
                        LineEdit { input-type: password; text: root.wifi_password; edited(val) => { root.wifi_password = val; } height: 35px; }
                    }
                    
                    HorizontalBox {
                        alignment: center; spacing: 15px; padding-top: 10px;
                        GlowingButton { text: "Back"; primary: false; height: 38px; clicked => { root.active_step = 1; } }
                        GlowingButton { text: "Rescan"; primary: false; height: 38px; clicked => { InstallerLogic.rescan_wifi(); } }
                        GlowingButton { 
                            text: "Connect & Continue"; primary: true; height: 38px;
                            clicked => { 
                                if (root.selected_network == "") {
                                    root.error_message = "Please select a Wi-Fi network from the list.";
                                    root.show_error_popup = true;
                                } else {
                                    InstallerLogic.connect_wifi(root.selected_network, root.wifi_password); 
                                }
                            } 
                        }
                    }
                }

                // =========================================================
                // STEP 3: Target Drive Selection Window (With Partition Bar)
                // =========================================================
                if (root.active_step == 3) : VerticalBox {
                    alignment: center; spacing: 12px; padding-left: 60px; padding-right: 60px;
                    Text { text: "Target Drive Selection"; font-size: 22px; font-weight: 700; color: #A5F3FC; horizontal-alignment: center; }
                    Text { text: "Choose the physical storage device where Kestrel Arch will be installed."; color: #9CA3AF; font-size: 12px; horizontal-alignment: center; }
                    
                    VerticalBox {
                        spacing: 6px;
                        Text { text: "Available Storage Drives:"; font-size: 12px; font-weight: 600; color: #D1D5DB; }
                        ComboBox { model: root.available_disks; current-value: root.selected_disk; selected(val) => { root.selected_disk = val; } height: 35px; }
                    }

                    PartitionVisualizer { disk_name: root.selected_disk; }
                    
                    HorizontalBox {
                        alignment: center; spacing: 15px; padding-top: 15px;
                        GlowingButton { text: "Back"; primary: false; clicked => { root.active_step = root.selected_mode == "1. Online (Download Latest)" ? 2 : 1; } }
                        GlowingButton { text: "Next Step"; primary: true; clicked => { root.active_step = 30; } }
                    }
                }

                // =========================================================
                // STEP 30: Partitioning Strategy Window
                // =========================================================
                if (root.active_step == 30) : VerticalBox {
                    alignment: center; spacing: 15px; padding-left: 40px; padding-right: 40px;
                    Text { text: "Partitioning Strategy"; font-size: 22px; font-weight: 700; color: #A5F3FC; horizontal-alignment: center; }
                    Text { text: "Select how you would like to structure partitions on " + root.selected_disk; color: #9CA3AF; font-size: 12px; horizontal-alignment: center; }
                    Rectangle { height: 5px; } 

                    VerticalBox {
                        spacing: 8px;
                        
                        RadioOption {
                            title: "Wipe Disk";
                            description: "Erase the entire drive and automatically build fresh partitions.";
                            active: root.selected_part == "1. WIPE (Erase Entire Disk)";
                            clicked => { root.selected_part = "1. WIPE (Erase Entire Disk)"; }
                        }
                        
                        RadioOption {
                            title: "Replace Partition";
                            description: "Format a specific target partition without touching the rest of the drive.";
                            active: root.selected_part == "2. REPLACE (Format Target Partition)";
                            clicked => { root.selected_part = "2. REPLACE (Format Target Partition)"; }
                        }
                        
                        RadioOption {
                            title: "Advanced Partition Manager";
                            description: "Launch native graphical layout manager to customize volumes.";
                            active: root.selected_part == "3. MANUAL (Advanced Partitioning)";
                            clicked => { root.selected_part = "3. MANUAL (Advanced Partitioning)"; }
                        }
                    }
                    
                    HorizontalBox {
                        alignment: center; spacing: 15px; padding-top: 15px;
                        GlowingButton { text: "Back"; primary: false; clicked => { root.active_step = 3; } }
                        GlowingButton { 
                            text: "Next Step"; 
                            primary: true; 
                            clicked => { 
                                if (root.selected_part == "1. WIPE (Erase Entire Disk)") { root.active_step = 31; } 
                                else if (root.selected_part == "2. REPLACE (Format Target Partition)") { root.active_step = 32; } 
                                else { root.active_step = 33; }
                            } 
                        }
                    }
                }

                // =========================================================
                // STEP 31: Wipe Specific Options Window
                // =========================================================
                if (root.active_step == 31) : VerticalBox {
                    alignment: center; spacing: 15px; padding-left: 60px; padding-right: 60px;
                    Text { text: "Configure Disk Wipe"; font-size: 22px; font-weight: 700; color: #A5F3FC; horizontal-alignment: center; }
                    
                    VerticalBox {
                        spacing: 10px;
                        Text { text: "⚠️ ERASING ENTIRE DISK"; color: #EF4444; font-size: 16px; font-weight: 800; horizontal-alignment: center; }
                        Text { text: "All data on " + root.selected_disk + " will be completely destroyed."; color: #9CA3AF; horizontal-alignment: center; wrap: word-wrap; }
                    }

                    VerticalBox {
                        spacing: 6px;
                        Text { text: "Select Base Filesystem:"; font-size: 13px; font-weight: 600; color: #D1D5DB; }
                        ComboBox { model: ["ext4", "btrfs"]; current-value: root.target_filesystem; selected(val) => { root.target_filesystem = val; } height: 38px; }
                    }

                    HorizontalBox {
                        alignment: center; spacing: 15px; padding-top: 20px;
                        GlowingButton { text: "Back"; primary: false; clicked => { root.active_step = 30; } }
                        GlowingButton { text: "Confirm & Continue"; primary: true; clicked => { root.active_step = 4; } }
                    }
                }

                // =========================================================
                // STEP 32: Replace Partition (With Partition Bar)
                // =========================================================
                if (root.active_step == 32) : VerticalBox {
                    alignment: center; spacing: 10px; padding-left: 60px; padding-right: 60px;
                    Text { text: "Replace Partition"; font-size: 20px; font-weight: 700; color: #A5F3FC; horizontal-alignment: center; }

                    PartitionVisualizer { disk_name: root.selected_disk; }

                    VerticalBox {
                        spacing: 4px;
                        Text { text: "Enter target partition path (e.g., /dev/sda2):"; font-size: 12px; font-weight: 600; color: #D1D5DB; }
                        LineEdit { text: root.replace_partition_path; edited(val) => { root.replace_partition_path = val; } height: 35px; }
                    }

                    VerticalBox {
                        spacing: 4px;
                        Text { text: "Select Filesystem:"; font-size: 12px; font-weight: 600; color: #D1D5DB; }
                        ComboBox { model: ["ext4", "btrfs"]; current-value: root.target_filesystem; selected(val) => { root.target_filesystem = val; } height: 35px; }
                    }

                    HorizontalBox {
                        alignment: center; spacing: 15px; padding-top: 10px;
                        GlowingButton { text: "Back"; primary: false; clicked => { root.active_step = 30; } }
                        GlowingButton { 
                            text: "Confirm & Continue"; 
                            primary: true; 
                            clicked => { 
                                if (root.replace_partition_path == "") {
                                    root.error_message = "Please provide the target partition path (e.g., /dev/sda2).";
                                    root.show_error_popup = true;
                                } else {
                                    root.active_step = 4; 
                                }
                            } 
                        }
                    }
                }

                // =========================================================
                // STEP 33: Advanced Partition Manager Window (GParted Data Loop)
                // =========================================================
                if (root.active_step == 33) : VerticalBox {
                    alignment: start; spacing: 12px; padding-left: 10px; padding-right: 10px;
                    
                    HorizontalBox {
                        alignment: space-between;
                        HorizontalBox {
                            spacing: 10px;
                            Text { text: "Storage device:"; color: #D1D5DB; font-size: 13px; font-weight: 600; vertical-alignment: center; }
                            ComboBox { model: root.available_disks; current-value: root.selected_disk; selected(val) => { root.selected_disk = val; } width: 280px; height: 32px; }
                        }
                    }

                    Rectangle {
                        border-width: 1px; border-color: #06B6D4; border-radius: 6px; background: #020617; height: 260px;
                        VerticalBox {
                            Rectangle {
                                background: #0F172A; height: 30px;
                                HorizontalBox {
                                    padding-left: 10px; padding-right: 10px; spacing: 10px;
                                    Text { text: "Name"; width: 140px; color: #E5E7EB; font-size: 11px; font-weight: 700; vertical-alignment: center; }
                                    Text { text: "File System"; width: 80px; color: #E5E7EB; font-size: 11px; font-weight: 700; vertical-alignment: center; }
                                    Text { text: "File System Label"; width: 110px; color: #E5E7EB; font-size: 11px; font-weight: 700; vertical-alignment: center; }
                                    Text { text: "Mount Point"; width: 90px; color: #E5E7EB; font-size: 11px; font-weight: 700; vertical-alignment: center; }
                                    Text { text: "Size"; color: #E5E7EB; font-size: 11px; font-weight: 700; vertical-alignment: center; horizontal-alignment: right; }
                                }
                            }
                            ScrollView {
                                VerticalBox {
                                    padding: 8px; spacing: 4px;
                                    for part in InstallerLogic.current_partitions : Rectangle {
                                        height: 28px; background: #1F293750; border-radius: 3px;
                                        HorizontalBox {
                                            padding-left: 8px; padding-right: 8px; spacing: 10px;
                                            HorizontalBox { spacing: 6px; width: 140px; alignment: start; Rectangle { width: 10px; height: 10px; background: part.color_hex; border-radius: 2px; } Text { text: part.name; color: #D1D5DB; font-size: 12px; vertical-alignment: center; } }
                                            Text { text: part.fstype; width: 80px; color: #D1D5DB; font-size: 12px; vertical-alignment: center; }
                                            Text { text: part.label; width: 110px; color: #D1D5DB; font-size: 12px; vertical-alignment: center; }
                                            Text { text: part.mountpoint; width: 90px; color: #D1D5DB; font-size: 12px; vertical-alignment: center; }
                                            Text { text: part.size; color: #D1D5DB; font-size: 12px; vertical-alignment: center; horizontal-alignment: right; }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    HorizontalBox {
                        alignment: space-between;
                        Text { text: "Use GParted to visually format your layout, then close it to refresh."; color: #F59E0B; font-size: 11px; vertical-alignment: center; }
                        GlowingButton { 
                            text: "Launch GParted"; primary: false; width: 140px; height: 32px; 
                            clicked => { InstallerLogic.launch_gparted(root.selected_disk); } 
                        }
                    }

                    HorizontalBox {
                        alignment: end; spacing: 12px; padding-top: 5px;
                        GlowingButton { text: "Back"; primary: false; width: 100px; height: 35px; clicked => { root.active_step = 30; } }
                        GlowingButton { text: "Next Step"; primary: true; width: 100px; height: 35px; clicked => { root.active_step = 4; } }
                    }
                }

                // =========================================================
                // STEP 4: Account Creation Window ONLY
                // =========================================================
                if (root.active_step == 4) : VerticalBox {
                    alignment: center; spacing: 10px; padding-left: 60px; padding-right: 60px;
                    Text { text: "User Credentials"; font-size: 22px; font-weight: 700; color: #A5F3FC; horizontal-alignment: center; }
                    Rectangle { height: 10px; } 

                    VerticalBox { spacing: 4px; Text { text: "System Hostname:"; font-size: 13px; font-weight: 500; color: #D1D5DB; } LineEdit { text: root.in_hostname; edited(val) => { root.in_hostname = val; } height: 38px; } }
                    VerticalBox { spacing: 4px; Text { text: "Username:"; font-size: 13px; font-weight: 500; color: #D1D5DB; } LineEdit { text: root.in_username; edited(val) => { root.in_username = val; } height: 38px; } }
                    VerticalBox { spacing: 4px; Text { text: "User Password:"; font-size: 13px; font-weight: 500; color: #D1D5DB; } LineEdit { input-type: password; text: root.in_password; edited(val) => { root.in_password = val; } height: 38px; } }
                    VerticalBox { spacing: 4px; Text { text: "Root Password (leave blank to match User):"; font-size: 13px; font-weight: 500; color: #D1D5DB; } LineEdit { input-type: password; text: root.in_root_password; edited(val) => { root.in_root_password = val; } height: 38px; } }

                    HorizontalBox {
                        alignment: center; spacing: 15px; padding-top: 20px;
                        GlowingButton { 
                            text: "Back"; primary: false; 
                            clicked => { 
                                if (root.selected_part == "1. WIPE (Erase Entire Disk)") { root.active_step = 31; }
                                else if (root.selected_part == "2. REPLACE (Format Target Partition)") { root.active_step = 32; }
                                else { root.active_step = 33; }
                            } 
                        }
                        
                        GlowingButton { 
                            text: "Next Step"; primary: true; 
                            clicked => { 
                                if (root.in_hostname == "" || root.in_username == "" || root.in_password == "") {
                                    root.error_message = "System Hostname, Username, and Password cannot be left blank.";
                                    root.show_error_popup = true;
                                } else { root.active_step = 5; }
                            } 
                        }
                    }
                }

                // =========================================================
                // STEP 5: Browser Selection Window (List with Descriptions)
                // =========================================================
                if (root.active_step == 5) : VerticalBox {
                    alignment: center; spacing: 10px; padding-left: 40px; padding-right: 40px;
                    Text { text: "Web Browser Selection"; font-size: 22px; font-weight: 700; color: #A5F3FC; horizontal-alignment: center; }
                    Text { text: "Choose your primary browser environment."; color: #9CA3AF; font-size: 12px; horizontal-alignment: center; }
                    Rectangle { height: 5px; }

                    Rectangle {
                        height: 250px; width: 100%; border-radius: 8px; border-width: 1px; border-color: #1F2937; background: #020617;
                        ScrollView {
                            width: 100%; height: 100%;
                            VerticalBox {
                                padding: 8px; spacing: 6px;
                                RadioOption { title: "1. Falkon Browser (Recommended)"; description: "Lightweight, lightning-fast Qt-based browser integrating seamlessly with KDE."; active: root.selected_browser == "1. Falkon Browser (Recommended)"; clicked => { root.selected_browser = "1. Falkon Browser (Recommended)"; } }
                                if (root.selected_mode != "2. Offline (Fast, Local Cache)") : RadioOption { title: "2. LibreWolf"; description: "Customized version of Firefox prioritizing security and privacy."; active: root.selected_browser == "2. LibreWolf"; clicked => { root.selected_browser = "2. LibreWolf"; } }
                                if (root.selected_mode != "2. Offline (Fast, Local Cache)") : RadioOption { title: "3. Firefox"; description: "The standard open-source web browser engine."; active: root.selected_browser == "3. Firefox"; clicked => { root.selected_browser = "3. Firefox"; } }
                                if (root.selected_mode != "2. Offline (Fast, Local Cache)") : RadioOption { title: "4. Brave"; description: "Chromium-based browser with built-in tracker blocking."; active: root.selected_browser == "4. Brave"; clicked => { root.selected_browser = "4. Brave"; } }
                            }
                        }
                    }
                    
                    HorizontalBox {
                        alignment: center; spacing: 15px; padding-top: 15px;
                        GlowingButton { text: "Back"; primary: false; clicked => { root.active_step = 4; } }
                        GlowingButton { text: "Next Step"; primary: true; clicked => { root.active_step = 51; } }
                    }
                }

                // =========================================================
                // STEP 51: Desktop Environment Selection (List with Descriptions)
                // =========================================================
                if (root.active_step == 51) : VerticalBox {
                    alignment: center; spacing: 8px; padding-left: 30px; padding-right: 30px;
                    Text { text: "Desktop Environment Setup"; font-size: 20px; font-weight: 700; color: #A5F3FC; horizontal-alignment: center; }
                    Text { text: "Select your window manager or workspace environment."; color: #9CA3AF; font-size: 12px; horizontal-alignment: center; }

                    Rectangle {
                        height: 270px; width: 100%; border-radius: 8px; border-width: 1px; border-color: #1F2937; background: #020617;
                        ScrollView {
                            width: 100%; height: 100%;
                            VerticalBox {
                                padding: 8px; spacing: 6px;
                                RadioOption { title: "1. Hyprland"; description: "Visually pleasing dynamic tiling Wayland compositor."; active: root.selected_de == "1. Hyprland"; clicked => { root.selected_de = "1. Hyprland"; } }
                                RadioOption { title: "2. KDE Plasma"; description: "Comprehensive, flexible desktop environment offering KWin."; active: root.selected_de == "2. KDE Plasma"; clicked => { root.selected_de = "2. KDE Plasma"; } }
                                RadioOption { title: "3. XFCE"; description: "Modern, lightweight, stable traditional desktop drop-down layout."; active: root.selected_de == "3. XFCE"; clicked => { root.selected_de = "3. XFCE"; } }
                                if (root.selected_mode != "2. Offline (Fast, Local Cache)") : RadioOption { title: "4. GNOME"; description: "User-friendly environment with a modern layout."; active: root.selected_de == "4. GNOME"; clicked => { root.selected_de = "4. GNOME"; } }
                                if (root.selected_mode != "2. Offline (Fast, Local Cache)") : RadioOption { title: "5. Sway"; description: "Tiling Wayland compositor; dynamic drop-in i3 upgrade."; active: root.selected_de == "5. Sway"; clicked => { root.selected_de = "5. Sway"; } }
                                if (root.selected_mode != "2. Offline (Fast, Local Cache)") : RadioOption { title: "6. i3-wm"; description: "Popular X11 tiling manager leveraging clean text configurations."; active: root.selected_de == "6. i3-wm"; clicked => { root.selected_de = "6. i3-wm"; } }
                                if (root.selected_mode != "2. Offline (Fast, Local Cache)") : RadioOption { title: "7. Cinnamon"; description: "Traditional desktop paradigm balancing internal features."; active: root.selected_de == "7. Cinnamon"; clicked => { root.selected_de = "7. Cinnamon"; } }
                                if (root.selected_mode != "2. Offline (Fast, Local Cache)") : RadioOption { title: "8. Niri"; description: "Scrollable tiling Wayland compositor optimizing fluid layout grid."; active: root.selected_de == "8. Niri"; clicked => { root.selected_de = "8. Niri"; } }
                                if (root.selected_mode != "2. Offline (Fast, Local Cache)") : RadioOption { title: "9. Qtile"; description: "Highly configurable environment scripted entirely in Python."; active: root.selected_de == "9. Qtile"; clicked => { root.selected_de = "9. Qtile"; } }
                                if (root.selected_mode != "2. Offline (Fast, Local Cache)") : RadioOption { title: "10. Wayfire"; description: "Wlroots Wayland engine mixing structural performance aesthetics."; active: root.selected_de == "10. Wayfire"; clicked => { root.selected_de = "10. Wayfire"; } }
                                if (root.selected_mode != "2. Offline (Fast, Local Cache)") : RadioOption { title: "11. bspwm"; description: "Binary space partitioning X11 architecture tracking strict layouts."; active: root.selected_de == "11. bspwm"; clicked => { root.selected_de = "11. bspwm"; } }
                                if (root.selected_mode != "2. Offline (Fast, Local Cache)") : RadioOption { title: "12. Budgie"; description: "Clean and elegant GTK interface prioritizing modern ergonomics."; active: root.selected_de == "12. Budgie"; clicked => { root.selected_de = "12. Budgie"; } }
                                if (root.selected_mode != "2. Offline (Fast, Local Cache)") : RadioOption { title: "13. Cosmic"; description: "Modern performance Rust workspace for absolute responsiveness."; active: root.selected_de == "13. Cosmic"; clicked => { root.selected_de = "13. Cosmic"; } }
                                if (root.selected_mode != "2. Offline (Fast, Local Cache)") : RadioOption { title: "14. LXDE"; description: "Fast, lightweight X11 environment tailored for legacy hardware."; active: root.selected_de == "14. LXDE"; clicked => { root.selected_de = "14. LXDE"; } }
                                if (root.selected_mode != "2. Offline (Fast, Local Cache)") : RadioOption { title: "15. LXQt"; description: "Blazing fast lightweight environment engineered on the Qt stack."; active: root.selected_de == "15. LXQt"; clicked => { root.selected_de = "15. LXQt"; } }
                                if (root.selected_mode != "2. Offline (Fast, Local Cache)") : RadioOption { title: "16. Mate"; description: "Classic GNOME 2 fork tracking legacy desktop layouts natively."; active: root.selected_de == "16. Mate"; clicked => { root.selected_de = "16. Mate"; } }
                                if (root.selected_mode != "2. Offline (Fast, Local Cache)") : RadioOption { title: "17. Openbox"; description: "Highly custom X11 window manager featuring extensive canvas styles."; active: root.selected_de == "17. Openbox"; clicked => { root.selected_de = "17. Openbox"; } }
                            }
                        }
                    }

                    HorizontalBox {
                        alignment: center; spacing: 15px; padding-top: 10px;
                        GlowingButton { text: "Back"; primary: false; clicked => { root.active_step = 5; } }
                        GlowingButton { 
                            text: "Next Step"; primary: true; 
                            clicked => { 
                                if (root.selected_de == "Choose your environment") {
                                    root.error_message = "Please select a Desktop Environment before proceeding.";
                                    root.show_error_popup = true;
                                } else { root.active_step = 52; }
                            } 
                        }
                    }
                }

                // =========================================================
                // STEP 52: Boot Manager & Initialization (List with Descriptions)
                // =========================================================
                if (root.active_step == 52) : VerticalBox {
                    alignment: center; spacing: 8px; padding-left: 40px; padding-right: 40px;
                    Text { text: "Boot Manager Setup"; font-size: 20px; font-weight: 700; color: #A5F3FC; horizontal-alignment: center; }
                    Text { text: "Select your bootloader and performance matrix configuration."; color: #9CA3AF; font-size: 12px; horizontal-alignment: center; }

                    Rectangle {
                        height: 180px; width: 100%; border-radius: 8px; border-width: 1px; border-color: #1F2937; background: #020617;
                        ScrollView {
                            width: 100%; height: 100%;
                            VerticalBox {
                                padding: 8px; spacing: 6px;
                                RadioOption { title: "1. GRUB"; description: "Flexible multi-boot loader; supports auto BTRFS snapshots."; active: root.selected_boot == "1. GRUB"; clicked => { root.selected_boot = "1. GRUB"; } }
                                RadioOption { title: "2. systemd-boot"; description: "Light minimalist EFI manager tracking kernel slots."; active: root.selected_boot == "2. systemd-boot"; clicked => { root.selected_boot = "2. systemd-boot"; } }
                                RadioOption { title: "3. rEFInd"; description: "Rich graphical shell automatically identifying boot options."; active: root.selected_boot == "3. rEFInd"; clicked => { root.selected_boot = "3. rEFInd"; } }
                                RadioOption { title: "4. Limine"; description: "Modern lightning-fast system deployed cleanly via limine.conf."; active: root.selected_boot == "4. Limine"; clicked => { root.selected_boot = "4. Limine"; } }
                            }
                        }
                    }

                    HorizontalBox {
                        alignment: start; spacing: 8px;
                        CheckBox { checked: root.perf_enabled; toggled => { root.perf_enabled = !root.perf_enabled; } }
                        Text { text: "Apply Hyper-Performance Matrix (ZRAM, Fast I/O, EarlyOOM)"; color: #D1D5DB; font-size: 12px; font-weight: 600; vertical-alignment: center; }
                    }

                    Text { text: "WARNING: Proceeding will formally execute installation logic."; color: #EF4444; font-size: 11px; font-weight: 700; horizontal-alignment: center; }
                    
                    HorizontalBox {
                        alignment: center; spacing: 15px; padding-top: 10px;
                        GlowingButton { text: "Back"; primary: false; clicked => { root.active_step = 51; } }
                        
                        GlowingButton { 
                            text: "Initialize Protocol"; primary: true; 
                            clicked => { 
                                root.active_step = 6;
                                InstallerLogic.start_install(
                                    root.selected_disk, root.selected_mode, root.selected_part,
                                    root.target_filesystem, root.replace_partition_path,
                                    root.gui_root_part, root.gui_efi_part,
                                    root.in_hostname, root.in_username, root.in_password,
                                    root.in_root_password, root.selected_browser,
                                    root.perf_enabled ? "Y" : "N", root.selected_de, root.selected_boot
                                );
                            } 
                        }
                    }
                }

                // =========================================================
                // STEP 6: Deployment Execution Screen (Crisp TextEdit Log)
                // =========================================================
                if (root.active_step == 6) : VerticalBox {
                    alignment: center; spacing: 15px; padding-left: 50px; padding-right: 50px;
                    Text { text: "DEPLOYING INFRASTRUCTURE"; font-size: 20px; font-weight: 800; color: #A5F3FC; horizontal-alignment: center; letter-spacing: 2px; }
                    ProgressIndicator { progress: InstallerLogic.progress; height: 22px; }
                    Text { text: InstallerLogic.status_text; color: #9CA3AF; font-size: 14px; horizontal-alignment: center; }

                    TouchArea {
                        mouse-cursor: pointer; height: 20px; clicked => { root.show_console = !root.show_console; }
                        Text {
                            text: root.show_console ? "▼ Hide Deployment Logs" : "▶ View Deployment Logs";
                            color: root.show_console ? #06B6D4 : #6B7280; font-size: 12px; font-weight: 600; horizontal-alignment: center; vertical-alignment: center; animate color { duration: 100ms; easing: ease-out; }
                        }
                    }

                    if (root.show_console) : Rectangle {
                        background: #000000; border-radius: 8px; border-width: 1px; border-color: #1F2937; height: 220px; width: 100%; clip: true; 
                        
                        // Implemented TextEdit to prevent blurriness and strange pixel-rendering 
                        TextEdit {
                            width: 100%;
                            height: 100%;
                            text: InstallerLogic.console_log;
                            font-size: 12px;
                            font-family: "Cascadia Code, Consolas, monospace";
                            read-only: true;
                            wrap: word-wrap;
                        }
                    }
                }

                // =========================================================
                // STEP 99: Success Screen
                // =========================================================
                if (root.active_step == 99) : VerticalBox {
                    alignment: center; spacing: 30px;
                    VerticalBox {
                        spacing: 15px;
                        Text { text: "DEPLOYMENT SUCCESSFUL"; font-size: 28px; font-weight: 800; color: #A5F3FC; horizontal-alignment: center; letter-spacing: 2px; }
                        Text { text: "Kestrel Arch has been successfully deployed.\nYou may now safely reboot your system."; color: #9CA3AF; font-size: 14px; horizontal-alignment: center; }
                    }
                    HorizontalBox {
                        alignment: center; spacing: 20px;
                        GlowingButton { text: "Power Off"; primary: false; clicked => { InstallerLogic.poweroff_system(); } }
                        GlowingButton { text: "Reboot Now"; primary: true; clicked => { InstallerLogic.reboot_system(); } }
                    }
                }
            }
        }
    }

    // ==========================================
    // ERROR MODAL OVERLAY
    // ==========================================
    if (root.show_error_popup) : Rectangle {
        width: 100%; height: 100%; background: #000000D0; TouchArea {}
        VerticalBox {
            alignment: center;
            HorizontalBox {
                alignment: center;
                Rectangle {
                    width: 550px; height: 250px; background: #040D14; border-radius: 12px; border-width: 1px; border-color: #EF4444; drop-shadow-color: #EF444440; drop-shadow-blur: 25px; 
                    VerticalBox {
                        padding: 30px; spacing: 20px; alignment: center;
                        Text { text: "ATTENTION NEEDED"; font-size: 18px; font-weight: 800; color: #EF4444; horizontal-alignment: center; letter-spacing: 1px; }
                        Text { text: root.error_message; font-size: 14px; color: #F3F4F6; horizontal-alignment: center; wrap: word-wrap; }
                        HorizontalBox { alignment: center; padding-top: 10px; GlowingButton { text: "Okay, got it!"; primary: false; clicked => { root.show_error_popup = false; } } }
                    }
                }
            }
        }
    }
}
