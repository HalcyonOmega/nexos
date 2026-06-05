use std::env;
use std::ffi::{OsStr, OsString};
use std::os::unix::process::CommandExt;
use std::path::Path;
use std::process::{Command, ExitCode};

const VERSION: &str = env!("CARGO_PKG_VERSION");

fn main() -> ExitCode {
    let args: Vec<OsString> = env::args_os().skip(1).collect();

    if args.is_empty() {
        print_help();
        return ExitCode::SUCCESS;
    }

    let command = args[0].to_string_lossy();
    let rest = &args[1..];

    match command.as_ref() {
        "-h" | "--help" | "help" => {
            print_help();
            ExitCode::SUCCESS
        }
        "--version" => {
            println!("nex {VERSION}");
            ExitCode::SUCCESS
        }
        "switch" | "boot" | "test" | "build" | "rollback" | "info" => {
            exec_os_command(command.as_ref(), rest)
        }
        "pkg" | "package" => exec_package_command(rest),
        "nix" | "raw" => exec_raw_nix(rest),
        "shell" => exec_shell(rest),
        "list" => exec_os_command("info", rest),
        "dry" | "dry-run" => exec_dry_run(rest),
        "install" => exec_passthrough("nixos-install", rest),
        "gen-config" | "generate-config" => exec_passthrough("nixos-generate-config", rest),
        "option" => exec_passthrough("nixos-option", rest),
        "version" => exec_passthrough("nixos-version", rest),
        "doctor" => doctor(),
        "edit" => edit(rest),
        _ => exec_with_prefix("nix", [command.as_ref()], rest),
    }
}

fn exec_package_command(args: &[OsString]) -> ExitCode {
    if args.is_empty() {
        eprintln!("nex: expected a package command after 'pkg'");
        eprintln!("try: nex pkg build .#name, nex pkg run .#name, or nex shell cmatrix");
        return ExitCode::from(2);
    }

    let command = args[0].to_string_lossy();
    let rest = &args[1..];

    if command == "shell" {
        exec_shell(rest)
    } else {
        exec_with_prefix("nix", [command.as_ref()], rest)
    }
}

fn exec_raw_nix(args: &[OsString]) -> ExitCode {
    if args.is_empty() {
        eprintln!("nex: expected a nix command after 'nix'");
        eprintln!("try: nex nix build .#name");
        return ExitCode::from(2);
    }

    exec_passthrough("nix", args)
}

fn exec_shell(args: &[OsString]) -> ExitCode {
    if uses_flake_shell(args) {
        exec_with_prefix("nix", ["shell"], args)
    } else if uses_legacy_package_shell(args) || has_non_package_flags(args) || args.is_empty() {
        exec_passthrough("nix-shell", args)
    } else {
        let mut shell_args = vec![OsString::from("-p")];
        shell_args.extend_from_slice(args);
        exec_passthrough("nix-shell", &shell_args)
    }
}

fn exec_os_command(command: &str, args: &[OsString]) -> ExitCode {
    let mut os_args = vec![OsString::from("os"), OsString::from(command)];

    if args.is_empty() && matches!(command, "switch" | "boot" | "test" | "build") {
        append_default_target(&mut os_args);
    } else {
        os_args.extend_from_slice(args);
    }

    exec_passthrough("nh", &os_args)
}

fn exec_dry_run(args: &[OsString]) -> ExitCode {
    let mut os_args = vec![
        OsString::from("os"),
        OsString::from("switch"),
        OsString::from("--dry"),
    ];

    if args.is_empty() {
        append_default_target(&mut os_args);
    } else {
        os_args.extend_from_slice(args);
    }

    exec_passthrough("nh", &os_args)
}

fn append_default_target(args: &mut Vec<OsString>) {
    args.push(OsString::from(active_config_root()));
    args.push(OsString::from("--hostname"));
    args.push(OsString::from("default"));
}

fn uses_legacy_package_shell(args: &[OsString]) -> bool {
    args.iter().any(|arg| {
        let value = arg.to_string_lossy();
        value == "-p" || value == "--packages"
    })
}

fn has_non_package_flags(args: &[OsString]) -> bool {
    args.iter().any(|arg| {
        let value = arg.to_string_lossy();
        value.starts_with('-') && value != "-p" && value != "--packages"
    })
}

fn uses_flake_shell(args: &[OsString]) -> bool {
    args.iter().any(|arg| {
        let value = arg.to_string_lossy();
        if value.starts_with('-') {
            matches!(
                value.as_ref(),
                "-f" | "--file"
                    | "--expr"
                    | "--system"
                    | "--impure"
                    | "--override-inputs"
                    | "--commit-lock-file"
            )
        } else {
            value.starts_with('.')
                || value.starts_with('/')
                || value.starts_with('~')
                || value.contains('#')
                || value.contains(':')
        }
    })
}

fn exec_with_prefix<const N: usize>(
    program: &str,
    prefix: [&str; N],
    rest: &[OsString],
) -> ExitCode {
    let mut command = Command::new(program);
    command.args(prefix);
    command.args(rest);
    exec(command)
}

fn exec_passthrough(program: &str, rest: &[OsString]) -> ExitCode {
    let mut command = Command::new(program);
    command.args(rest);
    exec(command)
}

fn exec(mut command: Command) -> ExitCode {
    let error = command.exec();
    eprintln!("nex: failed to execute command: {error}");
    ExitCode::from(127)
}

fn active_config_root() -> String {
    env::var("NEX_FLAKE").unwrap_or_else(|_| "/etc/nexos".into())
}

fn edit(args: &[OsString]) -> ExitCode {
    if !args.is_empty() {
        eprintln!("nex: edit does not accept arguments");
        eprintln!("hint: set NEX_FLAKE to choose a different config directory");
        return ExitCode::from(2);
    }

    let config_root = active_config_root();
    if !Path::new(&config_root).is_dir() {
        eprintln!("nex: config path does not exist: {config_root}");
        eprintln!("hint: set NEX_FLAKE to your Nexos configuration directory");
        return ExitCode::from(1);
    }

    let mut command = Command::new("sh");
    command.arg("-c");
    command.arg(r#"exec ${EDITOR:-vim} "${NEX_FLAKE:-/etc/nexos}""#);
    command.current_dir(&config_root);
    exec(command)
}

fn doctor() -> ExitCode {
    let checks = [
        ("nix", "generic Nix command"),
        ("nh", "Nexos system command backend"),
        ("nixos-version", "NixOS-compatible version command"),
    ];

    let mut failed = false;

    println!("Nexos doctor");

    for (program, description) in checks {
        if command_exists(program) {
            println!("ok   {program:<14} {description}");
        } else {
            println!("miss {program:<14} {description}");
            failed = true;
        }
    }

    let config_root = active_config_root();
    if Path::new(&config_root).is_dir() {
        println!("ok   NEX_FLAKE      {config_root}");
    } else if env::var("NEX_FLAKE").is_ok() {
        println!("miss NEX_FLAKE      {config_root} (path does not exist)");
        failed = true;
    } else {
        println!("warn NEX_FLAKE      not set; using {config_root}");
    }

    if failed {
        ExitCode::from(1)
    } else {
        ExitCode::SUCCESS
    }
}

fn command_exists(program: impl AsRef<OsStr>) -> bool {
    Command::new(program)
        .arg("--version")
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .status()
        .is_ok()
}

fn print_help() {
    println!(
        r#"nex {VERSION}

Nexos command-line interface.

Short OS lifecycle commands:
  nex switch [args...]      Build and activate the current Nexos system via nh
  nex boot [args...]        Build and make active on next boot
  nex test [args...]        Build and activate temporarily
  nex build [args...]       Build the system without activating it
  nex rollback [args...]    Roll back to the previous generation
  nex info                  Show system generation information
  nex list                  Alias for nex info
  nex dry-run               Preview the default Nexos system switch

Compatibility helpers:
  nex install [args...]     Install Nexos to a mounted target
  nex gen-config [args...]  Generate hardware/system config for a target
  nex option [args...]      Run nixos-option
  nex version [args...]     Run nixos-version
  nex doctor                Check the Nexos command environment
  nex edit                  Open the active config directory in $EDITOR

Generic Nix commands:
  nex flake [args...]       Work with flakes
  nex shell [packages...]   Start a package shell (nix-shell -p)
  nex shell .#dev           Start a flake shell when a flake ref is given
  nex develop [args...]     Start a development shell
  nex search [args...]      Search packages
  nex pkg build [args...]   Build packages
  nex nix <command>         Run a raw nix command through the nex prefix

Fallback:
  Commands not claimed by Nexos are passed to nix unchanged.
  Use nex nix <command> when you specifically need raw Nix behavior.
"#
    );
}
