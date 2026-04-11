pub mod arch;
pub mod debian;
pub mod raspbian;

use anyhow::Result;
use os_info::{Info, Type};

/// Represents an abstract interface for target Operating Systems.
pub trait SystemPlatform {
    /// Returns the display name of the operating system.
    fn display_name(&self) -> &'static str;

    /// Runs the bootstrap initialization logic for the platform.
    fn bootstrap(&self) -> Result<()>;
}

/// Detects the underlying OS and returns its corresponding SystemPlatform trait object.
pub fn get_platform() -> Option<Box<dyn SystemPlatform>> {
    let info = os_info::get();
    detect_from_info(&info)
}

/// Pure logic for OS detection extracted for easy unit testing.
fn detect_from_info(info: &Info) -> Option<Box<dyn SystemPlatform>> {
    match info.os_type() {
        Type::Debian => Some(Box::new(debian::Debian)),
        Type::Arch => Some(Box::new(arch::Arch)),
        Type::Raspbian => Some(Box::new(raspbian::Raspbian)),
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
        assert_eq!(platform.display_name(), "Debian LTS");
    }

    #[test]
    fn test_detect_arch() {
        let info = Info::with_type(Type::Arch);
        let platform = detect_from_info(&info).expect("Should detect Arch");
        assert_eq!(platform.display_name(), "Arch Linux");
    }

    #[test]
    fn test_detect_raspbian() {
        let info = Info::with_type(Type::Raspbian);
        let platform = detect_from_info(&info).expect("Should detect Raspbian");
        assert_eq!(platform.display_name(), "Raspberry Pi OS (Raspbian)");
    }

    #[test]
    fn test_detect_unknown() {
        let info = Info::with_type(Type::Windows);
        let platform = detect_from_info(&info);
        assert!(platform.is_none());
    }
}
