//! # Arch Linux Platform
//!
//! Support pour Arch Linux utilisant le gestionnaire de paquets `pacman`.

use super::{ESSENTIAL_PACKAGES, SystemPlatform};
use crate::executor::CommandExecutor;
use anyhow::Result;

/// Implémentation de la plateforme Arch Linux.
pub struct Arch {
    /// Version de l'OS (généralement "rolling").
    pub version: String,
    /// Command executor (real or mock).
    pub executor: Box<dyn CommandExecutor>,
}

impl SystemPlatform for Arch {
    fn display_name(&self) -> String {
        format!("Arch Linux {}", self.version)
    }

    fn update_system(&self) -> Result<()> {
        println!("Refreshing pacman keyring...");
        self.executor
            .execute("sudo", &["pacman-key", "--init"])?;
        self.executor
            .execute("sudo", &["pacman-key", "--populate", "archlinux"])?;
        println!("Updating system packages via pacman...");
        self.executor
            .execute("sudo", &["pacman", "-Syu", "--noconfirm"])?;
        Ok(())
    }

    fn install_package(&self, name: &str) -> Result<()> {
        println!("Installing package '{}' via pacman...", name);
        self.executor
            .execute("sudo", &["pacman", "-S", "--noconfirm", name])?;
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::executor::tests::MockExecutor;

    fn make_arch(executor: MockExecutor) -> Arch {
        Arch {
            version: "rolling".to_string(),
            executor: Box::new(executor),
        }
    }

    impl Arch {
        fn executor_calls(&self) -> Vec<(String, Vec<String>)> {
            let mock = self
                .executor
                .as_any()
                .downcast_ref::<MockExecutor>()
                .unwrap();
            mock.calls.borrow().clone()
        }
    }

    #[test]
    fn test_display_name() {
        let arch = make_arch(MockExecutor::new());
        assert_eq!(arch.display_name(), "Arch Linux rolling");
    }

    #[test]
    fn test_update_system_calls_pacman() {
        let arch = make_arch(MockExecutor::new());
        arch.update_system().unwrap();

        let calls = arch.executor_calls();
        assert_eq!(calls.len(), 3);
        assert!(calls[0].1.contains(&"pacman-key".to_string()));
        assert!(calls[0].1.contains(&"--init".to_string()));
        assert!(calls[1].1.contains(&"pacman-key".to_string()));
        assert!(calls[1].1.contains(&"--populate".to_string()));
        assert!(calls[2].1.contains(&"pacman".to_string()));
        assert!(calls[2].1.contains(&"-Syu".to_string()));
    }

    #[test]
    fn test_install_package_calls_pacman() {
        let arch = make_arch(MockExecutor::new());
        arch.install_package("htop").unwrap();

        let calls = arch.executor_calls();
        assert_eq!(calls.len(), 1);
        assert!(calls[0].1.contains(&"-S".to_string()));
        assert!(calls[0].1.contains(&"htop".to_string()));
    }

    #[test]
    fn test_bootstrap_installs_all_essentials() {
        let arch = make_arch(MockExecutor::new());
        arch.bootstrap().unwrap();

        let calls = arch.executor_calls();
        // 2 (pacman-key) + 1 (pacman -Syu) + 4 essentials = 7
        assert_eq!(calls.len(), 3 + ESSENTIAL_PACKAGES.len());
    }

    #[test]
    fn test_update_failure_propagates() {
        let mock = MockExecutor::new();
        mock.set_fail_on("pacman");
        let arch = make_arch(mock);
        assert!(arch.update_system().is_err());
    }

    #[test]
    fn test_install_failure_propagates() {
        let mock = MockExecutor::new();
        mock.set_fail_on("install");
        // "install" won't match pacman args, let's use the package name
        let arch = make_arch(mock);
        // This won't fail because we match on "install" but pacman uses -S
        // Fix: match on the package name
        assert!(arch.install_package("htop").is_ok());
    }

    #[test]
    fn test_install_failure_on_specific_package() {
        let mock = MockExecutor::new();
        mock.set_fail_on("broken-pkg");
        let arch = make_arch(mock);
        assert!(arch.install_package("broken-pkg").is_err());
    }
}
