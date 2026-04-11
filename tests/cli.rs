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

    // On a supported OS it succeeds with SYSTEM SUMMARY output
    // On unsupported OS it fails gracefully with an error message
    let output = result.get_output().clone();
    let stdout = String::from_utf8_lossy(&output.stdout);
    let stderr = String::from_utf8_lossy(&output.stderr);

    let is_supported = stdout.contains("SYSTEM SUMMARY");
    let is_unsupported = stderr.contains("non supporté") || stderr.contains("not supported");

    assert!(
        is_supported || is_unsupported,
        "Expected either system summary or unsupported error, got stdout={stdout}, stderr={stderr}"
    );
}
