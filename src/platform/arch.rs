//! # Arch Linux Platform
//!
//! Support pour Arch Linux utilisant le gestionnaire de paquets `pacman`.

use super::SystemPlatform;
use anyhow::Result;
use std::process::Command;

/// Implémentation de la plateforme Arch Linux.
pub struct Arch {
    /// Version de l'OS (généralement "rolling").
    pub version: String,
}

impl SystemPlatform for Arch {
    fn display_name(&self) -> String {
        format!("Arch Linux {}", self.version)
    }

    fn update_system(&self) -> Result<()> {
        println!("Updating system packages via pacman...");

        let status = Command::new("sudo")
            .args(["pacman", "-Syu", "--noconfirm"])
            .status()?;

        if !status.success() {
            anyhow::bail!("Failed to run pacman -Syu");
        }
        Ok(())
    }

    fn install_package(&self, name: &str) -> Result<()> {
        println!("Installing package '{}' via pacman...", name);
        let status = Command::new("sudo")
            .args(["pacman", "-S", "--noconfirm", name])
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
