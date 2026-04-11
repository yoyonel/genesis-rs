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
    use crate::platform::get_platform;
    use anyhow::{Context, Result};

    /// Exécute l'action principale (détection ou bootstrap).
    pub fn run_bootstrap() -> Result<()> {
        let platform =
            get_platform().context("Système d'exploitation non supporté ou non détecté.")?;

        platform.print_summary();
        platform.bootstrap()?;

        Ok(())
    }

    /// Exécute uniquement la détection et affiche le résumé matériel.
    pub fn run_detect() -> Result<()> {
        let platform =
            get_platform().context("Système d'exploitation non supporté ou non détecté.")?;

        platform.print_summary();

        Ok(())
    }
}
