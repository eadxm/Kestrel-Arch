slint::include_modules!();

use std::process::{Command, Stdio};
use std::io::{BufRead, BufReader};
use std::thread;

fn main() -> Result<(), slint::PlatformError> {
    let ui = InstallerWindow::new()?;
    let ui_handle = ui.as_weak();
    
    ui.global::<InstallerLogic>().on_start_install(move |target_disk| {
        let ui_handle = ui_handle.clone();
        
        thread::spawn(move || {
            // Executes the existing bash script inside your live ISO runtime environment
            let mut child = Command::new("bash")
                .arg("/usr/local/bin/install.sh") 
                .env("TARGET_DISK", target_disk.as_str())
                .env("NON_INTERACTIVE", "1") 
                .stdout(Stdio::piped())
                .stderr(Stdio::piped())
                .spawn()
                .expect("Failed to execute Kestrel bash script");

            let stdout = child.stdout.take().expect("Failed to capture stdout");
            let reader = BufReader::new(stdout);

            let mut current_progress: f32 = 0.0;

            for line in reader.lines() {
                if let Ok(output) = line {
                    // Adjust progress bars based on string matches from your install.sh script logs
                    if output.contains("Formatting") || output.contains("partition") {
                        current_progress = 0.25;
                    } else if output.contains("pacstrap") || output.contains("Installing") {
                        current_progress = 0.60;
                    } else if output.contains("bootloader") || output.contains("grub") || output.contains("limine") {
                        current_progress = 0.85;
                    }

                    let status_text = output.clone();
                    slint::invoke_from_event_loop({
                        let ui_handle = ui_handle.clone();
                        move || {
                            if let Some(ui) = ui_handle.upgrade() {
                                ui.global::<InstallerLogic>().set_status_text(status_text.into());
                                ui.global::<InstallerLogic>().set_progress(current_progress);
                            }
                        }
                    }).unwrap();
                }
            }
            
            let status = child.wait().expect("Failed to wait on backend process");

            slint::invoke_from_event_loop({
                let ui_handle = ui_handle.clone();
                move || {
                    if let Some(ui) = ui_handle.upgrade() {
                        if status.success() {
                            ui.global::<InstallerLogic>().set_progress(1.0);
                            ui.set_active_step(3); 
                        } else {
                            ui.global::<InstallerLogic>().set_status_text("Installation failed! Check console output.".into());
                        }
                    }
                }
            }).unwrap();
        });
    });

    ui.run()
}
