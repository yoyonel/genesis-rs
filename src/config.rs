//! # Configuration
//!
//! Loads package lists and bootstrap settings from a TOML file.
//! Falls back to built-in defaults if no config file is found.

use anyhow::{Context, Result};
use serde::Deserialize;
use std::path::Path;

/// Default config file path.
pub const DEFAULT_CONFIG_PATH: &str = "genesis.toml";

/// Top-level configuration.
#[derive(Debug, Default, Deserialize, PartialEq)]
#[serde(default)]
pub struct Config {
    /// Packages shared across all platforms.
    pub packages: PackageConfig,
}

/// Per-platform package lists.
#[derive(Debug, Deserialize, PartialEq)]
#[serde(default)]
pub struct PackageConfig {
    /// Packages installed on all platforms.
    pub common: Vec<String>,
    /// Additional packages for Debian.
    pub debian: Vec<String>,
    /// Additional packages for Arch Linux.
    pub arch: Vec<String>,
    /// Additional packages for Raspberry Pi OS.
    pub raspbian: Vec<String>,
}

impl Default for PackageConfig {
    fn default() -> Self {
        Self {
            common: vec!["git".into(), "curl".into(), "vim".into(), "htop".into()],
            debian: Vec::new(),
            arch: Vec::new(),
            raspbian: Vec::new(),
        }
    }
}

/// Load configuration from a TOML file, or return defaults if the file doesn't exist.
pub fn load_config(path: &Path) -> Result<Config> {
    if !path.exists() {
        return Ok(Config::default());
    }
    let content = std::fs::read_to_string(path)
        .with_context(|| format!("Failed to read config file: {}", path.display()))?;
    let config: Config = toml::from_str(&content).with_context(|| "Failed to parse TOML config")?;
    Ok(config)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;
    use tempfile::NamedTempFile;

    #[test]
    fn test_default_config() {
        let config = Config::default();
        assert_eq!(config.packages.common, vec!["git", "curl", "vim", "htop"]);
        assert!(config.packages.debian.is_empty());
        assert!(config.packages.arch.is_empty());
        assert!(config.packages.raspbian.is_empty());
    }

    #[test]
    fn test_load_missing_file_returns_defaults() {
        let config = load_config(Path::new("/nonexistent/genesis.toml")).unwrap();
        assert_eq!(config, Config::default());
    }

    #[test]
    fn test_load_custom_config() {
        let mut f = NamedTempFile::new().unwrap();
        writeln!(
            f,
            r#"
[packages]
common = ["git", "wget"]
debian = ["build-essential"]
arch = ["base-devel"]
"#
        )
        .unwrap();

        let config = load_config(f.path()).unwrap();
        assert_eq!(config.packages.common, vec!["git", "wget"]);
        assert_eq!(config.packages.debian, vec!["build-essential"]);
        assert_eq!(config.packages.arch, vec!["base-devel"]);
        assert!(config.packages.raspbian.is_empty());
    }

    #[test]
    fn test_load_partial_config_uses_defaults() {
        let mut f = NamedTempFile::new().unwrap();
        writeln!(
            f,
            r#"
[packages]
debian = ["nginx"]
"#
        )
        .unwrap();

        let config = load_config(f.path()).unwrap();
        // common gets default values
        assert_eq!(config.packages.common, vec!["git", "curl", "vim", "htop"]);
        assert_eq!(config.packages.debian, vec!["nginx"]);
    }

    #[test]
    fn test_load_invalid_toml_returns_error() {
        let mut f = NamedTempFile::new().unwrap();
        writeln!(f, "this is not valid toml {{{{").unwrap();
        assert!(load_config(f.path()).is_err());
    }
}
