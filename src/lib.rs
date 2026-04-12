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

pub mod executor;
pub mod platform;

/// Point d'entrée pour la logique métier du bootstrap.
pub mod app {
    use crate::executor::{CommandExecutor, DryRunExecutor};
    use crate::platform::{get_platform, get_platform_with_executor};
    use anyhow::{Context, Result};

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
    pub fn run_bootstrap(dry_run: bool) -> Result<()> {
        let platform = resolve_platform(dry_run)?;

        platform.print_summary();
        platform.bootstrap()?;

        Ok(())
    }

    /// Exécute uniquement la détection et affiche le résumé matériel.
    pub fn run_detect() -> Result<()> {
        let platform = resolve_platform(false)?;

        platform.print_summary();

        Ok(())
    }
}
