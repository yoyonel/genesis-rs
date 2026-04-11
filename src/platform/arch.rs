use super::SystemPlatform;
use anyhow::{Ok, Result};

/// Arch Linux platform implementation.
pub struct Arch;

impl SystemPlatform for Arch {
    fn display_name(&self) -> &'static str {
        "Arch Linux"
    }

    fn bootstrap(&self) -> Result<()> {
        println!("Bootstrapping {}...", self.display_name());
        println!("Running pacman -Syu & configuring base system...");
        // Add actual logic here
        Ok(())
    }
}
