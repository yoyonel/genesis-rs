//! # Debian Platform
//!
//! Support pour les distributions basées sur Debian utilisant le gestionnaire de paquets `apt`.

use super::SystemPlatform;
use anyhow::Result;
use std::process::Command;

/// Implémentation de la plateforme Debian.
pub struct Debian {
    /// Version spécifique de Debian (ex: "12").
    pub version: String,
}

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
            .args([
                "apt-get",
                "upgrade",
                "-y",
                "-o",
                "Dpkg::Options::=--force-confold",
            ])
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
            .args([
                "apt-get",
                "install",
                "-y",
                "-o",
                "Dpkg::Options::=--force-confold",
                name,
            ])
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
