use super::SystemPlatform;
use anyhow::{Ok, Result};

/// Debian platform implementation.
pub struct Debian {
    pub version: String,
}

use std::process::Command;

impl SystemPlatform for Debian {
    fn display_name(&self) -> String {
        format!("Debian {}", self.version)
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
