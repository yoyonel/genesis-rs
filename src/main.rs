mod cli;

use anyhow::Result;
use clap::Parser;
use cli::{Cli, Commands};
use genesis_rs::app;

fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Bootstrap => app::run_bootstrap()?,
        Commands::Detect => app::run_detect()?,
    }

    Ok(())
}
