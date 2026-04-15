use clap::{Parser, Subcommand};
use std::path::PathBuf;

/// Command Line Interface root structure.
#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
pub struct Cli {
    /// subcommand to execute
    #[command(subcommand)]
    pub command: Commands,

    /// Preview commands without executing them
    #[arg(long, global = true)]
    pub dry_run: bool,

    /// Path to TOML configuration file
    #[arg(long, global = true)]
    pub config: Option<PathBuf>,

    /// Enable verbose (debug-level) logging
    #[arg(short, long, global = true)]
    pub verbose: bool,
}

/// Available subcommands for genesis-rs.
#[derive(Subcommand, Debug)]
pub enum Commands {
    /// Bootstrap the Linux installation
    Bootstrap,

    /// Detect the current operating system and display information
    Detect,
}
