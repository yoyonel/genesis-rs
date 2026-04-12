use assert_cmd::Command;
use predicates::prelude::*;

#[test]
fn test_help_flag() {
    Command::cargo_bin("genesis-rs")
        .unwrap()
        .arg("--help")
        .assert()
        .success()
        .stdout(predicate::str::contains("bootstrap"))
        .stdout(predicate::str::contains("detect"));
}

#[test]
fn test_version_flag() {
    Command::cargo_bin("genesis-rs")
        .unwrap()
        .arg("--version")
        .assert()
        .success()
        .stdout(predicate::str::contains("genesis-rs"));
}

#[test]
fn test_no_args_shows_help() {
    Command::cargo_bin("genesis-rs")
        .unwrap()
        .assert()
        .failure()
        .stderr(predicate::str::contains("Usage"));
}

#[test]
fn test_invalid_subcommand() {
    Command::cargo_bin("genesis-rs")
        .unwrap()
        .arg("invalid-command")
        .assert()
        .failure()
        .stderr(predicate::str::contains("error"));
}

#[test]
fn test_detect_subcommand_runs() {
    // detect should succeed on any Linux system (CI or dev machine)
    // It may fail on unsupported OS but should not panic
    let result = Command::cargo_bin("genesis-rs")
        .unwrap()
        .arg("detect")
        .assert();

    // On a supported OS it succeeds with SYSTEM SUMMARY output (in stderr via tracing)
    // On unsupported OS it fails gracefully with an error message
    let output = result.get_output().clone();
    let stderr = String::from_utf8_lossy(&output.stderr);

    let is_supported = stderr.contains("SYSTEM SUMMARY");
    let is_unsupported = stderr.contains("non supporté") || stderr.contains("not supported");

    assert!(
        is_supported || is_unsupported,
        "Expected either system summary or unsupported error, got stderr={stderr}"
    );
}

#[test]
fn test_bootstrap_dry_run() {
    // --dry-run should print commands without executing them
    let result = Command::cargo_bin("genesis-rs")
        .unwrap()
        .args(["--dry-run", "bootstrap"])
        .assert();

    let output = result.get_output().clone();
    let stdout = String::from_utf8_lossy(&output.stdout);
    let stderr = String::from_utf8_lossy(&output.stderr);

    // On a supported OS: dry-run outputs [dry-run] prefixed commands to stdout
    // On unsupported OS: fails gracefully
    let is_dry_run = stdout.contains("[dry-run]");
    let is_unsupported = stderr.contains("non supporté") || stderr.contains("not supported");

    assert!(
        is_dry_run || is_unsupported,
        "Expected dry-run output or unsupported error, got stdout={stdout}, stderr={stderr}"
    );
}
