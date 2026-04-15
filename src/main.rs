mod cli;

use anyhow::Result;
use clap::Parser;
use cli::{Cli, Commands};
use genesis_rs::app;
use tracing_subscriber::EnvFilter;

fn main() -> Result<()> {
    let cli = Cli::parse();

    let default_directive = if cli.verbose {
        "genesis_rs=debug"
    } else {
        "genesis_rs=info"
    };

    tracing_subscriber::fmt()
        .with_writer(std::io::stderr)
        .with_env_filter(EnvFilter::from_default_env().add_directive(default_directive.parse()?))
        .init();

    match cli.command {
        Commands::Bootstrap => app::run_bootstrap(cli.dry_run, cli.config.as_deref())?,
        Commands::Detect => app::run_detect()?,
    }

    Ok(())
}
