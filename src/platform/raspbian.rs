//! # Raspbian Platform
//!
//! Support pour Raspberry Pi OS (anciennement Raspbian) utilisant le gestionnaire de paquets `apt`.

use super::{ESSENTIAL_PACKAGES, SystemPlatform, apt_install_package, apt_update_system};
use crate::executor::CommandExecutor;
use anyhow::Result;

/// Implémentation de la plateforme Raspberry Pi OS.
pub struct Raspbian {
    /// Version de l'OS (ex: "12").
    pub version: String,
    /// Command executor (real or mock).
    pub executor: Box<dyn CommandExecutor>,
}

impl SystemPlatform for Raspbian {
    fn display_name(&self) -> String {
        format!("Raspberry Pi OS {}", self.version)
    }

    fn update_system(&self) -> Result<()> {
        apt_update_system(self.executor.as_ref())
    }

    fn install_package(&self, name: &str) -> Result<()> {
        apt_install_package(self.executor.as_ref(), name)
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

    fn make_raspbian(executor: MockExecutor) -> Raspbian {
        Raspbian {
            version: "12".to_string(),
            executor: Box::new(executor),
        }
    }

    impl Raspbian {
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
        let rpi = make_raspbian(MockExecutor::new());
        assert_eq!(rpi.display_name(), "Raspberry Pi OS 12");
    }

    #[test]
    fn test_update_system_calls_apt() {
        let rpi = make_raspbian(MockExecutor::new());
        rpi.update_system().unwrap();

        let calls = rpi.executor_calls();
        assert_eq!(calls.len(), 2);
        assert!(calls[0].1.contains(&"apt-get".to_string()));
        assert!(calls[0].1.contains(&"update".to_string()));
        assert!(calls[1].1.contains(&"upgrade".to_string()));
    }

    #[test]
    fn test_install_package_calls_apt() {
        let rpi = make_raspbian(MockExecutor::new());
        rpi.install_package("htop").unwrap();

        let calls = rpi.executor_calls();
        assert_eq!(calls.len(), 1);
        assert!(calls[0].1.contains(&"install".to_string()));
        assert!(calls[0].1.contains(&"htop".to_string()));
    }

    #[test]
    fn test_bootstrap_installs_all_essentials() {
        let rpi = make_raspbian(MockExecutor::new());
        rpi.bootstrap().unwrap();

        let calls = rpi.executor_calls();
        assert_eq!(calls.len(), 2 + ESSENTIAL_PACKAGES.len());
    }

    #[test]
    fn test_update_failure_propagates() {
        let mock = MockExecutor::new();
        mock.set_fail_on("apt-get update");
        let rpi = make_raspbian(mock);
        assert!(rpi.update_system().is_err());
    }

    #[test]
    fn test_bootstrap_stops_on_update_failure() {
        let mock = MockExecutor::new();
        mock.set_fail_on("apt-get update");
        let rpi = make_raspbian(mock);
        assert!(rpi.bootstrap().is_err());
        let calls = rpi.executor_calls();
        assert_eq!(calls.len(), 1);
    }
}
