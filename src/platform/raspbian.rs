use super::SystemPlatform;
use anyhow::{Ok, Result};

/// Raspbian (Raspberry Pi OS) platform implementation.
pub struct Raspbian;

impl SystemPlatform for Raspbian {
    fn display_name(&self) -> &'static str {
        "Raspberry Pi OS (Raspbian)"
    }

    fn bootstrap(&self) -> Result<()> {
        println!("Bootstrapping {}...", self.display_name());
        println!("Running apt-get update & configure ARM-specific base system...");
        // Add actual logic here
        Ok(())
    }
}
