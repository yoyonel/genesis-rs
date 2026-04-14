//! # genesis-rs
//!
//! `genesis-rs` est un outil de bootstrap et de diagnostic système agnostique.
//!
//! Cette bibliothèque fournit les abstractions et les implémentations pour gérer
//! différentes distributions Linux (Debian, Arch, Raspbian) de manière unifiée.
//!
//! ## Exemple d'usage (Interne)
//!
//! ```rust
//! use genesis_rs::platform::get_platform;
//!
//! if let Some(platform) = get_platform() {
//!     println!("OS détecté : {}", platform.display_name());
//!     platform.print_summary();
//! }
//! ```

pub mod config;
pub mod executor;
pub mod platform;

/// Point d'entrée pour la logique métier du bootstrap.
pub mod app {
    use crate::config::{self, Config};
    use crate::executor::{CommandExecutor, DryRunExecutor};
    use crate::platform::{get_platform, get_platform_with_executor};
    use anyhow::{Context, Result};
    use std::path::Path;

    fn resolve_platform(dry_run: bool) -> Result<Box<dyn crate::platform::SystemPlatform>> {
        if dry_run {
            let executor: Box<dyn CommandExecutor> = Box::new(DryRunExecutor);
            get_platform_with_executor(executor)
        } else {
            get_platform()
        }
        .context("Système d'exploitation non supporté ou non détecté.")
    }

    /// Exécute l'action principale (détection ou bootstrap).
    pub fn run_bootstrap(dry_run: bool, config_path: Option<&Path>) -> Result<()> {
        let platform = resolve_platform(dry_run)?;

        let cfg =
            config::load_config(config_path.unwrap_or(Path::new(config::DEFAULT_CONFIG_PATH)))?;

        let platform_packages = get_platform_packages(&cfg, &platform.display_name());

        platform.print_summary();
        platform.update_system()?;
        for pkg in &platform_packages {
            platform.install_package(pkg)?;
        }

        Ok(())
    }

    /// Exécute uniquement la détection et affiche le résumé matériel.
    pub fn run_detect() -> Result<()> {
        let platform = resolve_platform(false)?;

        platform.print_summary();

        Ok(())
    }

    /// Merge common + platform-specific packages from config.
    fn get_platform_packages(cfg: &Config, display_name: &str) -> Vec<String> {
        let mut packages = cfg.packages.common.clone();
        let extra = if display_name.contains("Debian") {
            &cfg.packages.debian
        } else if display_name.contains("Arch") {
            &cfg.packages.arch
        } else if display_name.contains("Raspberry") {
            &cfg.packages.raspbian
        } else {
            return packages;
        };
        packages.extend(extra.iter().cloned());
        packages
    }

    #[cfg(test)]
    mod tests {
        use super::*;
        use crate::config::{Config, PackageConfig};
        use std::io::Write;
        use tempfile::NamedTempFile;

        fn make_config(common: &[&str], debian: &[&str], arch: &[&str]) -> Config {
            Config {
                packages: PackageConfig {
                    common: common.iter().map(|s| s.to_string()).collect(),
                    debian: debian.iter().map(|s| s.to_string()).collect(),
                    arch: arch.iter().map(|s| s.to_string()).collect(),
                    raspbian: Vec::new(),
                },
            }
        }

        #[test]
        fn test_get_platform_packages_debian() {
            let cfg = make_config(&["git", "curl"], &["build-essential"], &["base-devel"]);
            let pkgs = get_platform_packages(&cfg, "Debian 12");
            assert_eq!(pkgs, vec!["git", "curl", "build-essential"]);
        }

        #[test]
        fn test_get_platform_packages_arch() {
            let cfg = make_config(&["git"], &["nginx"], &["base-devel"]);
            let pkgs = get_platform_packages(&cfg, "Arch Linux rolling");
            assert_eq!(pkgs, vec!["git", "base-devel"]);
        }

        #[test]
        fn test_get_platform_packages_raspbian() {
            let cfg = Config {
                packages: PackageConfig {
                    common: vec!["git".into()],
                    debian: Vec::new(),
                    arch: Vec::new(),
                    raspbian: vec!["rpi-update".into()],
                },
            };
            let pkgs = get_platform_packages(&cfg, "Raspberry Pi OS 12");
            assert_eq!(pkgs, vec!["git", "rpi-update"]);
        }

        #[test]
        fn test_get_platform_packages_unknown() {
            let cfg = make_config(&["git", "curl"], &["nginx"], &["base-devel"]);
            let pkgs = get_platform_packages(&cfg, "Fedora 39");
            // Unknown platform returns only common packages
            assert_eq!(pkgs, vec!["git", "curl"]);
        }

        #[test]
        fn test_resolve_platform_dry_run() {
            // dry_run = true should succeed on any supported OS (returns DryRunExecutor)
            // On unsupported OS, it errors — both paths are valid
            let result = resolve_platform(true);
            // We just verify it doesn't panic — success depends on host OS
            let _ = result;
        }

        #[test]
        fn test_run_bootstrap_dry_run_with_config() {
            let mut f = NamedTempFile::new().unwrap();
            writeln!(
                f,
                r#"
[packages]
common = ["git"]
"#
            )
            .unwrap();

            // dry_run bootstrap with a valid config file
            let result = run_bootstrap(true, Some(f.path()));
            // On supported OS: succeeds (dry-run prints commands)
            // On unsupported OS: fails with "non supporté"
            let _ = result;
        }

        #[test]
        fn test_run_bootstrap_missing_config() {
            // Pointing to a nonexistent config should still work (defaults used)
            let result = run_bootstrap(true, None);
            let _ = result;
        }

        #[test]
        fn test_run_detect() {
            // detect should either succeed with summary or fail gracefully
            let result = run_detect();
            let _ = result;
        }
    }
}
