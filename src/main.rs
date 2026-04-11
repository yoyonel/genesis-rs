mod cli;
mod platform;

use anyhow::{Result, anyhow};
use clap::Parser;
use cli::{Cli, Commands};
use platform::get_platform;

fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Bootstrap => {
            let platform =
                get_platform().ok_or_else(|| anyhow!("Unsupported operating system detected."))?;

            platform.print_summary();
            platform.bootstrap()?;
        }
        Commands::Detect => {
            if let Some(platform) = get_platform() {
                platform.print_summary();
            } else {
                println!("Unsupported operating system.");
                println!("System Info: {:?}", os_info::get());
            }
        }
    }

    Ok(())
}
