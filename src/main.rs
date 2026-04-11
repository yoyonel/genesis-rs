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

            println!("Detected Platform: {}", platform.display_name());
            platform.bootstrap()?;
        }
        Commands::Detect => {
            if let Some(platform) = get_platform() {
                println!("Supported Platform Detected: {}", platform.display_name());
            } else {
                println!("Unsupported operating system.");
                println!("System Info: {:?}", os_info::get());
            }
        }
    }

    Ok(())
}
