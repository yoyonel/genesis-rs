//! # Platform Module
//!
//! Ce module contient les abstractions nécessaires pour supporter différentes
//! distributions Linux. Il définit le trait [`SystemPlatform`] qui doit être
//! implémenté par chaque OS supporté.

use anyhow::Result;
use os_info::{Info, Type};
use sysinfo::{Disks, System};

pub mod arch;
pub mod debian;
pub mod raspbian;

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

/// Détecte l'OS actuel et retourne une implémentation de [`SystemPlatform`].
///
/// Retourne `None` si la distribution n'est pas supportée.
pub fn get_platform() -> Option<Box<dyn SystemPlatform>> {
    let info = os_info::get();
    detect_from_info(&info)
}

/// Logique de détection à partir des informations système de `os_info`.
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
