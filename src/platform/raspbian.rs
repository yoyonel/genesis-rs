use super::SystemPlatform;
use anyhow::{Ok, Result};

/// Raspbian (Raspberry Pi OS) platform implementation.
pub struct Raspbian;

use std::process::Command;

impl SystemPlatform for Raspbian {
    fn display_name(&self) -> &'static str {
        "Raspberry Pi OS (Raspbian)"
    }

    fn update_system(&self) -> Result<()> {
        println!("Updating system packages via apt...");
        
        let status = Command::new("sudo")
            .env("DEBIAN_FRONTEND", "noninteractive")
            .args(["apt-get", "update"])
            .status()?;
        if !status.success() {
            anyhow::bail!("Failed to run apt-get update");
        }

        let status = Command::new("sudo")
            .env("DEBIAN_FRONTEND", "noninteractive")
            .args(["apt-get", "upgrade", "-y", "-o", "Dpkg::Options::=--force-confold"])
            .status()?;
        if !status.success() {
            anyhow::bail!("Failed to run apt-get upgrade");
        }

        Ok(())
    }

    fn install_package(&self, name: &str) -> Result<()> {
        println!("Installing package '{}' via apt...", name);
        let status = Command::new("sudo")
            .env("DEBIAN_FRONTEND", "noninteractive")
            .args(["apt-get", "install", "-y", "-o", "Dpkg::Options::=--force-confold", name])
            .status()?;
        
        if !status.success() {
            anyhow::bail!("Failed to install package: {}", name);
        }
        Ok(())
    }

    fn bootstrap(&self) -> Result<()> {
        println!("Bootstrapping {}...", self.display_name());
        self.update_system()?;
        
        // Default essential packages
        let essentials = vec!["git", "curl", "vim", "htop"];
        for pkg in essentials {
            self.install_package(pkg)?;
        }

        Ok(())
    }
}
