//! # Command Executor
//!
//! Abstraction over system command execution, enabling both real execution
//! and mock-based testing of platform operations.

use anyhow::Result;
use std::any::Any;
use std::process::Command;

/// Trait abstracting command execution for testability.
///
/// All platform operations that shell out to system commands go through this
/// trait, allowing unit tests to inject a mock executor instead of actually
/// running `sudo apt-get` or `sudo pacman`.
pub trait CommandExecutor {
    /// Execute a command with the given program and arguments.
    /// Returns `Ok(())` on success (exit code 0), or an error otherwise.
    fn execute(&self, program: &str, args: &[&str]) -> Result<()>;

    /// Execute a command with the given program, arguments, and environment variables.
    /// Returns `Ok(())` on success (exit code 0), or an error otherwise.
    fn execute_with_env(&self, program: &str, args: &[&str], env: &[(&str, &str)]) -> Result<()>;

    /// Downcast support for test assertions.
    fn as_any(&self) -> &dyn Any;
}

/// Real command executor that delegates to `std::process::Command`.
pub struct RealExecutor;

impl CommandExecutor for RealExecutor {
    fn execute(&self, program: &str, args: &[&str]) -> Result<()> {
        let status = Command::new(program).args(args).status()?;
        if !status.success() {
            anyhow::bail!("Command failed: {} {}", program, args.join(" "));
        }
        Ok(())
    }

    fn execute_with_env(&self, program: &str, args: &[&str], env: &[(&str, &str)]) -> Result<()> {
        let mut cmd = Command::new(program);
        cmd.args(args);
        for (key, value) in env {
            cmd.env(key, value);
        }
        let status = cmd.status()?;
        if !status.success() {
            anyhow::bail!("Command failed: {} {}", program, args.join(" "));
        }
        Ok(())
    }

    fn as_any(&self) -> &dyn Any {
        self
    }
}

/// Dry-run executor that logs commands without executing them.
///
/// Used with `--dry-run` CLI flag to preview what bootstrap would do.
pub struct DryRunExecutor;

impl CommandExecutor for DryRunExecutor {
    fn execute(&self, program: &str, args: &[&str]) -> Result<()> {
        println!("[dry-run] {} {}", program, args.join(" "));
        Ok(())
    }

    fn execute_with_env(&self, program: &str, args: &[&str], env: &[(&str, &str)]) -> Result<()> {
        let env_str: Vec<String> = env.iter().map(|(k, v)| format!("{k}={v}")).collect();
        println!(
            "[dry-run] {} {} {}",
            env_str.join(" "),
            program,
            args.join(" ")
        );
        Ok(())
    }

    fn as_any(&self) -> &dyn Any {
        self
    }
}

#[cfg(test)]
pub mod tests {
    use super::*;
    use std::any::Any;
    use std::cell::RefCell;

    /// A mock executor that records all commands without executing them.
    pub struct MockExecutor {
        pub calls: RefCell<Vec<(String, Vec<String>)>>,
        /// If set, the next call will return this error.
        pub fail_on: RefCell<Option<String>>,
    }

    impl MockExecutor {
        pub fn new() -> Self {
            Self {
                calls: RefCell::new(Vec::new()),
                fail_on: RefCell::new(None),
            }
        }

        /// Configure the mock to fail when a command containing `pattern` is seen.
        pub fn set_fail_on(&self, pattern: &str) {
            *self.fail_on.borrow_mut() = Some(pattern.to_string());
        }
    }

    impl CommandExecutor for MockExecutor {
        fn execute(&self, program: &str, args: &[&str]) -> Result<()> {
            let full_cmd = format!("{} {}", program, args.join(" "));
            self.calls.borrow_mut().push((
                program.to_string(),
                args.iter().map(|s| s.to_string()).collect(),
            ));

            if let Some(ref pattern) = *self.fail_on.borrow() {
                if full_cmd.contains(pattern) {
                    anyhow::bail!("Mock failure: {}", full_cmd);
                }
            }
            Ok(())
        }

        fn execute_with_env(
            &self,
            program: &str,
            args: &[&str],
            _env: &[(&str, &str)],
        ) -> Result<()> {
            self.execute(program, args)
        }

        fn as_any(&self) -> &dyn Any {
            self
        }
    }
}
