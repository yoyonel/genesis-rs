//! # Debian Platform
//!
//! Support pour les distributions basées sur Debian utilisant le gestionnaire de paquets `apt`.

use super::{ESSENTIAL_PACKAGES, SystemPlatform, apt_install_package, apt_update_system};
use crate::executor::CommandExecutor;
use anyhow::Result;

/// Implémentation de la plateforme Debian.
pub struct Debian {
    /// Version spécifique de Debian (ex: "12").
    pub version: String,
    /// Command executor (real or mock).
    pub executor: Box<dyn CommandExecutor>,
}

impl SystemPlatform for Debian {
    fn display_name(&self) -> String {
        format!("Debian {}", self.version)
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

    fn make_debian(executor: MockExecutor) -> Debian {
        Debian {
            version: "12".to_string(),
            executor: Box::new(executor),
        }
    }

    #[test]
    fn test_display_name() {
        let deb = make_debian(MockExecutor::new());
        assert_eq!(deb.display_name(), "Debian 12");
    }

    #[test]
    fn test_update_system_calls_apt() {
        let mock = MockExecutor::new();
        let deb = make_debian(mock);
        deb.update_system().unwrap();

        let calls = deb.executor_calls();
        assert_eq!(calls.len(), 2);
        assert!(calls[0].1.contains(&"apt-get".to_string()));
        assert!(calls[0].1.contains(&"update".to_string()));
        assert!(calls[1].1.contains(&"upgrade".to_string()));
    }

    #[test]
    fn test_install_package_calls_apt() {
        let mock = MockExecutor::new();
        let deb = make_debian(mock);
        deb.install_package("htop").unwrap();

        let calls = deb.executor_calls();
        assert_eq!(calls.len(), 1);
        assert!(calls[0].1.contains(&"install".to_string()));
        assert!(calls[0].1.contains(&"htop".to_string()));
    }

    #[test]
    fn test_bootstrap_installs_all_essentials() {
        let mock = MockExecutor::new();
        let deb = make_debian(mock);
        deb.bootstrap().unwrap();

        let calls = deb.executor_calls();
        // 2 (update+upgrade) + 4 essentials = 6
        assert_eq!(calls.len(), 2 + ESSENTIAL_PACKAGES.len());
    }

    #[test]
    fn test_update_failure_propagates() {
        let mock = MockExecutor::new();
        mock.set_fail_on("apt-get update");
        let deb = make_debian(mock);
        let result = deb.update_system();
        assert!(result.is_err());
    }

    #[test]
    fn test_install_failure_propagates() {
        let mock = MockExecutor::new();
        mock.set_fail_on("install");
        let deb = make_debian(mock);
        let result = deb.install_package("broken-pkg");
        assert!(result.is_err());
    }

    #[test]
    fn test_bootstrap_stops_on_update_failure() {
        let mock = MockExecutor::new();
        mock.set_fail_on("apt-get update");
        let deb = make_debian(mock);
        let result = deb.bootstrap();
        assert!(result.is_err());
        // Should have stopped after first command
        let calls = deb.executor_calls();
        assert_eq!(calls.len(), 1);
    }

    impl Debian {
        /// Helper for tests: extract recorded calls from the mock.
        fn executor_calls(&self) -> Vec<(String, Vec<String>)> {
            let mock = self
                .executor
                .as_any()
                .downcast_ref::<MockExecutor>()
                .unwrap();
            mock.calls.borrow().clone()
        }
    }
}
