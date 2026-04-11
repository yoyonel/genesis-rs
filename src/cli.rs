use clap::{Parser, Subcommand};

/// Command Line Interface root structure.
#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
pub struct Cli {
    /// subcommand to execute
    #[command(subcommand)]
    pub command: Commands,
}

/// Available subcommands for genesis-rs.
#[derive(Subcommand, Debug)]
pub enum Commands {
    /// Bootstrap the Linux installation
    Bootstrap,

    /// Detect the current operating system and display information
    Detect,
}
