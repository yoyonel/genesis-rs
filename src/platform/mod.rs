pub mod arch;
pub mod debian;
pub mod raspbian;

use anyhow::Result;
use os_info::{Info, Type};
use sysinfo::{Disks, System};

/// Represents an abstract interface for target Operating Systems.
pub trait SystemPlatform {
    /// Returns the display name of the operating system.
    fn display_name(&self) -> String;

    /// Runs the bootstrap initialization logic for the platform.
    fn bootstrap(&self) -> Result<()>;

    /// Updates the system packages to their latest versions.
    fn update_system(&self) -> Result<()>;

    /// Installs a specific package by name.
    fn install_package(&self, name: &str) -> Result<()>;

    /// Prints a summary of the system hardware and OS.
    fn print_summary(&self) {
        let mut sys = System::new_all();
        sys.refresh_all();

        println!("--- SYSTEM SUMMARY ---");
        println!("OS:         {}", self.display_name());

        if let Some(cpu) = sys.cpus().first() {
            println!("CPU:        {} ({} cores)", cpu.brand(), sys.cpus().len());
        }

        println!(
            "RAM:        {:.2} GB",
            sys.total_memory() as f64 / 1024.0 / 1024.0 / 1024.0
        );

        let disks = Disks::new_with_refreshed_list();
        for disk in &disks {
            println!(
                "Disk:       {:?} ({:.2} GB) - {:?}",
                disk.mount_point(),
                disk.total_space() as f64 / 1024.0 / 1024.0 / 1024.0,
                disk.file_system()
            );
        }
        println!("----------------------");
    }
}

/// Detects the underlying OS and returns its corresponding SystemPlatform trait object.
pub fn get_platform() -> Option<Box<dyn SystemPlatform>> {
    let info = os_info::get();
    detect_from_info(&info)
}

/// Pure logic for OS detection extracted for easy unit testing.
fn detect_from_info(info: &Info) -> Option<Box<dyn SystemPlatform>> {
    let version = info.version().to_string();
    match info.os_type() {
        Type::Debian => Some(Box::new(debian::Debian { version })),
        Type::Arch => Some(Box::new(arch::Arch { version })),
        Type::Raspbian => Some(Box::new(raspbian::Raspbian { version })),
        // We can add more specific OS matching logic if needed here
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_detect_debian() {
        let info = Info::with_type(Type::Debian);
        let platform = detect_from_info(&info).expect("Should detect Debian");
        assert!(platform.display_name().contains("Debian"));
    }

    #[test]
    fn test_detect_arch() {
        let info = Info::with_type(Type::Arch);
        let platform = detect_from_info(&info).expect("Should detect Arch");
        assert!(platform.display_name().contains("Arch Linux"));
    }

    #[test]
    fn test_detect_raspbian() {
        let info = Info::with_type(Type::Raspbian);
        let platform = detect_from_info(&info).expect("Should detect Raspbian");
        assert!(platform.display_name().contains("Raspberry Pi OS"));
    }

    #[test]
    fn test_detect_unknown() {
        let info = Info::with_type(Type::Windows);
        let platform = detect_from_info(&info);
        assert!(platform.is_none());
    }
}
