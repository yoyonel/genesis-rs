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
/// Only `display_name` differs between the two.
pub struct AptPlatform {
    /// Display name prefix (e.g., "Debian", "Raspberry Pi OS").
    pub name: &'static str,
    /// Version string (e.g., "12").
    pub version: String,
    /// Command executor (real or mock).
    pub executor: Box<dyn CommandExecutor>,
}

impl SystemPlatform for AptPlatform {
    fn display_name(&self) -> String {
        format!("{} {}", self.name, self.version)
    }

    fn update_system(&self) -> Result<()> {
        println!("Updating system packages via apt...");
        self.executor.execute(
            "sudo",
            &["DEBIAN_FRONTEND=noninteractive", "apt-get", "update"],
        )?;
        self.executor.execute(
            "sudo",
            &[
                "DEBIAN_FRONTEND=noninteractive",
                "apt-get",
                "upgrade",
                "-y",
                "-o",
                "Dpkg::Options::=--force-confold",
            ],
        )?;
        Ok(())
    }

    fn install_package(&self, name: &str) -> Result<()> {
        println!("Installing package '{}' via apt...", name);
        self.executor.execute(
            "sudo",
            &[
                "DEBIAN_FRONTEND=noninteractive",
                "apt-get",
                "install",
                "-y",
                "-o",
                "Dpkg::Options::=--force-confold",
                name,
            ],
        )?;
        Ok(())
    }

    fn bootstrap(&self) -> Result<()> {
        println!("Bootstrapping {}...", self.display_name());
        self.update_system()?;
        for pkg in ESSENTIAL_PACKAGES {
            self.install_package(pkg)?;
        }
        Ok(())
    }
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
        Type::Debian => Some(Box::new(AptPlatform {
            name: "Debian",
            version,
            executor,
        })),
        Type::Arch => Some(Box::new(arch::Arch { version, executor })),
        Type::Raspbian => Some(Box::new(AptPlatform {
            name: "Raspberry Pi OS",
            version,
            executor,
        })),
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

    fn make_apt(name: &'static str) -> AptPlatform {
        AptPlatform {
            name,
            version: "12".to_string(),
            executor: mock_executor(),
        }
    }

    fn apt_calls(platform: &AptPlatform) -> Vec<(String, Vec<String>)> {
        let mock = platform
            .executor
            .as_any()
            .downcast_ref::<MockExecutor>()
            .unwrap();
        mock.calls.borrow().clone()
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

    // --- AptPlatform tests ---

    #[test]
    fn test_apt_display_name_debian() {
        let apt = make_apt("Debian");
        assert_eq!(apt.display_name(), "Debian 12");
    }

    #[test]
    fn test_apt_display_name_raspbian() {
        let apt = make_apt("Raspberry Pi OS");
        assert_eq!(apt.display_name(), "Raspberry Pi OS 12");
    }

    #[test]
    fn test_apt_update_system() {
        let apt = make_apt("Debian");
        apt.update_system().unwrap();

        let calls = apt_calls(&apt);
        assert_eq!(calls.len(), 2);
        assert!(calls[0].1.contains(&"apt-get".to_string()));
        assert!(calls[0].1.contains(&"update".to_string()));
        assert!(calls[1].1.contains(&"upgrade".to_string()));
    }

    #[test]
    fn test_apt_install_package() {
        let apt = make_apt("Debian");
        apt.install_package("htop").unwrap();

        let calls = apt_calls(&apt);
        assert_eq!(calls.len(), 1);
        assert!(calls[0].1.contains(&"install".to_string()));
        assert!(calls[0].1.contains(&"htop".to_string()));
    }

    #[test]
    fn test_apt_bootstrap_installs_all_essentials() {
        let apt = make_apt("Debian");
        apt.bootstrap().unwrap();

        let calls = apt_calls(&apt);
        // 2 (update+upgrade) + 4 essentials = 6
        assert_eq!(calls.len(), 2 + ESSENTIAL_PACKAGES.len());
    }

    #[test]
    fn test_apt_update_failure_propagates() {
        let mock = MockExecutor::new();
        mock.set_fail_on("apt-get update");
        let apt = AptPlatform {
            name: "Debian",
            version: "12".to_string(),
            executor: Box::new(mock),
        };
        assert!(apt.update_system().is_err());
    }

    #[test]
    fn test_apt_install_failure_propagates() {
        let mock = MockExecutor::new();
        mock.set_fail_on("install");
        let apt = AptPlatform {
            name: "Debian",
            version: "12".to_string(),
            executor: Box::new(mock),
        };
        assert!(apt.install_package("broken-pkg").is_err());
    }

    #[test]
    fn test_apt_bootstrap_stops_on_update_failure() {
        let mock = MockExecutor::new();
        mock.set_fail_on("apt-get update");
        let apt = AptPlatform {
            name: "Debian",
            version: "12".to_string(),
            executor: Box::new(mock),
        };
        assert!(apt.bootstrap().is_err());
        let calls = apt_calls(&apt);
        assert_eq!(calls.len(), 1);
    }
}
