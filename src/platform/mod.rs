//! # Platform Module
//!
//! Ce module contient les abstractions nécessaires pour supporter différentes
//! distributions Linux. Il définit le trait [`SystemPlatform`] qui doit être
//! implémenté par chaque OS supporté.

use crate::executor::{CommandExecutor, RealExecutor};
use anyhow::Result;
use os_info::{Info, Type};
use sysinfo::{Disks, System};

pub mod arch;
pub mod debian;
pub mod raspbian;

/// Default essential packages installed during bootstrap.
pub const ESSENTIAL_PACKAGES: &[&str] = &["git", "curl", "vim", "htop"];

/// Interface unifiée pour la gestion des systèmes d'exploitation cibles.
///
/// Chaque distribution (Debian, Arch, etc.) implémente ce trait pour
/// traduire les commandes génériques en commandes spécifiques (ex: `apt` vs `pacman`).
pub trait SystemPlatform {
    /// Retourne le nom d'affichage complet du système (ex: "Debian 12.0.0").
    fn display_name(&self) -> String;

    /// Exécute la séquence complète de bootstrap pour cette plateforme.
    /// Cela inclut généralement la mise à jour des dépôts et l'installation
    /// des paquets essentiels.
    fn bootstrap(&self) -> Result<()>;

    /// Met à jour les paquets du système vers leur dernière version stable.
    fn update_system(&self) -> Result<()>;

    /// Installe un paquet spécifique par son nom technique.
    fn install_package(&self, name: &str) -> Result<()>;

    /// Affiche un résumé détaillé des caractéristiques matérielles (CPU, RAM, Disques).
    fn print_summary(&self) {
        let mut sys = System::new_all();
        sys.refresh_all();

        println!("--- SYSTEM SUMMARY ---");
        println!("OS:         {}", self.display_name());

        if let Some(cpu) = sys.cpus().first() {
            let brand = cpu.brand();
            let arch = std::env::consts::ARCH;
            if brand.is_empty() {
                println!("CPU:        {} ({} cores)", arch, sys.cpus().len());
            } else {
                println!(
                    "CPU:        {} {} ({} cores)",
                    arch,
                    brand,
                    sys.cpus().len()
                );
            }
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

/// Common implementation for apt-based distributions (Debian, Raspbian).
///
/// Factored out to avoid code duplication between Debian and Raspbian,
/// which share the same package manager and command structure.
pub(crate) fn apt_update_system(executor: &dyn CommandExecutor) -> Result<()> {
    println!("Updating system packages via apt...");
    executor.execute_with_env(
        "sudo",
        &["apt-get", "update"],
        &[("DEBIAN_FRONTEND", "noninteractive")],
    )?;
    executor.execute_with_env(
        "sudo",
        &[
            "apt-get",
            "upgrade",
            "-y",
            "-o",
            "Dpkg::Options::=--force-confold",
        ],
        &[("DEBIAN_FRONTEND", "noninteractive")],
    )?;
    Ok(())
}

/// Common implementation for apt-based package installation.
pub(crate) fn apt_install_package(executor: &dyn CommandExecutor, name: &str) -> Result<()> {
    println!("Installing package '{}' via apt...", name);
    executor.execute_with_env(
        "sudo",
        &[
            "apt-get",
            "install",
            "-y",
            "-o",
            "Dpkg::Options::=--force-confold",
            name,
        ],
        &[("DEBIAN_FRONTEND", "noninteractive")],
    )?;
    Ok(())
}

/// Détecte l'OS actuel et retourne une implémentation de [`SystemPlatform`].
///
/// Retourne `None` si la distribution n'est pas supportée.
pub fn get_platform() -> Option<Box<dyn SystemPlatform>> {
    let executor = RealExecutor;
    let info = os_info::get();
    detect_from_info(&info, Box::new(executor))
}

/// Logique de détection à partir des informations système de `os_info`.
fn detect_from_info(
    info: &Info,
    executor: Box<dyn CommandExecutor>,
) -> Option<Box<dyn SystemPlatform>> {
    let version = info.version().to_string();
    match info.os_type() {
        Type::Debian => Some(Box::new(debian::Debian { version, executor })),
        Type::Arch => Some(Box::new(arch::Arch { version, executor })),
        Type::Raspbian => Some(Box::new(raspbian::Raspbian { version, executor })),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::executor::tests::MockExecutor;

    fn mock_executor() -> Box<dyn CommandExecutor> {
        Box::new(MockExecutor::new())
    }

    #[test]
    fn test_detect_debian() {
        let info = Info::with_type(Type::Debian);
        let platform = detect_from_info(&info, mock_executor()).expect("Should detect Debian");
        assert!(platform.display_name().contains("Debian"));
    }

    #[test]
    fn test_detect_arch() {
        let info = Info::with_type(Type::Arch);
        let platform = detect_from_info(&info, mock_executor()).expect("Should detect Arch");
        assert!(platform.display_name().contains("Arch Linux"));
    }

    #[test]
    fn test_detect_raspbian() {
        let info = Info::with_type(Type::Raspbian);
        let platform = detect_from_info(&info, mock_executor()).expect("Should detect Raspbian");
        assert!(platform.display_name().contains("Raspberry Pi OS"));
    }

    #[test]
    fn test_detect_unknown() {
        let info = Info::with_type(Type::Windows);
        let platform = detect_from_info(&info, mock_executor());
        assert!(platform.is_none());
    }
}
