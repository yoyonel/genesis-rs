mod cli;

use anyhow::Result;
use clap::Parser;
use cli::{Cli, Commands};
use genesis_rs::app;
use tracing_subscriber::EnvFilter;

fn main() -> Result<()> {
    tracing_subscriber::fmt()
        .with_writer(std::io::stderr)
        .with_env_filter(EnvFilter::from_default_env().add_directive("genesis_rs=info".parse()?))
        .init();

    let cli = Cli::parse();

    match cli.command {
        Commands::Bootstrap => app::run_bootstrap(cli.dry_run)?,
        Commands::Detect => app::run_detect()?,
    }

    Ok(())
}
