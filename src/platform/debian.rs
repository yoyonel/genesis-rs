use super::SystemPlatform;
use anyhow::{Ok, Result};

/// Debian platform implementation.
pub struct Debian;

impl SystemPlatform for Debian {
    fn display_name(&self) -> &'static str {
        "Debian LTS"
    }

    fn bootstrap(&self) -> Result<()> {
        println!("Bootstrapping {}...", self.display_name());
        println!("Running apt-get update & configure base system...");
        // Add actual logic here
        Ok(())
    }
}
