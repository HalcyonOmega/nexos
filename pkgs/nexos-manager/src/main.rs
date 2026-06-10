use std::env;
use std::fs;
use std::io::{Read, Write};
use std::path::{Path, PathBuf};
use std::sync::mpsc::{self, Receiver, Sender};
use std::thread;

use eframe::egui;
use portable_pty::{native_pty_system, CommandBuilder, PtySize};

const COMMANDS: &[CommandSpec] = &[
    CommandSpec::new(
        "Switch",
        &["switch"],
        "Build and activate the system",
        "System",
    ),
    CommandSpec::new("Boot", &["boot"], "Build for the next boot", "System"),
    CommandSpec::new("Test", &["test"], "Activate temporarily", "System"),
    CommandSpec::new("Build", &["build"], "Build the active system", "System"),
    CommandSpec::new("Dry Run", &["dry-run"], "Preview a system switch", "System"),
    CommandSpec::new(
        "Rollback",
        &["rollback"],
        "Roll back one generation",
        "System",
    ),
    CommandSpec::new(
        "Clean",
        &["clean"],
        "Remove old generations and optimise the store",
        "Maintenance",
    ),
    CommandSpec::new(
        "Doctor",
        &["doctor"],
        "Check the Nexos command environment",
        "Maintenance",
    ),
    CommandSpec::new("Info", &["info"], "Show generation information", "Maintenance"),
    CommandSpec::new("Flake", &["flake"], "Run nix flake commands", "Tools"),
    CommandSpec::new("Shell", &["shell"], "Start a shell", "Tools"),
    CommandSpec::new("Develop", &["develop"], "Start a dev shell", "Tools"),
    CommandSpec::new("Search", &["search"], "Search packages", "Tools"),
    CommandSpec::new("Package Build", &["pkg", "build"], "Build a package", "Tools"),
    CommandSpec::new("Option", &["option"], "Run nixos-option", "Tools"),
    CommandSpec::new("Version", &["version"], "Run nixos-version", "Tools"),
    CommandSpec::new("Raw Nix", &["nix"], "Run a raw nix command", "Tools"),
];

const CATEGORIES: &[&str] = &["System", "Maintenance", "Tools"];

#[derive(Clone, Copy)]
struct CommandSpec {
    label: &'static str,
    args: &'static [&'static str],
    description: &'static str,
    category: &'static str,
}

impl CommandSpec {
    const fn new(
        label: &'static str,
        args: &'static [&'static str],
        description: &'static str,
        category: &'static str,
    ) -> Self {
        Self {
            label,
            args,
            description,
            category,
        }
    }
}

#[derive(Clone)]
struct ConfigRoot {
    path: PathBuf,
    source: &'static str,
}

enum ProcessEvent {
    Output(String),
    Finished(String),
}

enum ProcessInput {
    Text(String),
    Stop,
}

struct RunningProcess {
    title: String,
    rx: Receiver<ProcessEvent>,
    tx: Sender<ProcessInput>,
}

struct NexosManagerApp {
    config_root: Option<ConfigRoot>,
    selected_command: usize,
    extra_args: String,
    input: String,
    output: String,
    running: Option<RunningProcess>,
    last_status: String,
}

impl Default for NexosManagerApp {
    fn default() -> Self {
        let config_root = resolve_config_root();
        let last_status = match &config_root {
            Some(root) => format!("Active config: {}", root.path.display()),
            None => "No active config found. Set NEX_FLAKE or create /etc/nexos or /etc/nixos."
                .to_string(),
        };

        Self {
            config_root,
            selected_command: 0,
            extra_args: String::new(),
            input: String::new(),
            output: String::new(),
            running: None,
            last_status,
        }
    }
}

const ACCENT: egui::Color32 = egui::Color32::from_rgb(99, 155, 255);
const SUBTLE: egui::Color32 = egui::Color32::from_rgb(140, 145, 160);

impl eframe::App for NexosManagerApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        self.collect_process_events(ctx);

        egui::TopBottomPanel::top("header")
            .frame(
                egui::Frame::side_top_panel(&ctx.style())
                    .inner_margin(egui::Margin::symmetric(14.0, 10.0)),
            )
            .show(ctx, |ui| {
                ui.horizontal(|ui| {
                    ui.label(
                        egui::RichText::new("Nexos Manager")
                            .size(20.0)
                            .strong()
                            .color(ACCENT),
                    );
                    ui.add_space(8.0);
                    if let Some(root) = &self.config_root {
                        ui.label(
                            egui::RichText::new(format!(
                                "{}  ·  {}",
                                root.path.display(),
                                root.source
                            ))
                            .color(SUBTLE),
                        );
                    } else {
                        ui.colored_label(
                            egui::Color32::from_rgb(220, 100, 100),
                            "config not found — set NEX_FLAKE or create /etc/nexos",
                        );
                    }

                    ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                        if ui.button("Open Config").clicked() {
                            self.open_config();
                        }
                    });
                });
            });

        egui::TopBottomPanel::bottom("statusbar")
            .frame(
                egui::Frame::side_top_panel(&ctx.style())
                    .inner_margin(egui::Margin::symmetric(14.0, 6.0)),
            )
            .show(ctx, |ui| {
                ui.horizontal(|ui| {
                    if let Some(process) = &self.running {
                        ui.spinner();
                        ui.label(
                            egui::RichText::new(format!("Running {}", process.title))
                                .color(ACCENT),
                        );
                    } else {
                        ui.label(egui::RichText::new(&self.last_status).color(SUBTLE));
                    }
                });
            });

        egui::SidePanel::left("commands")
            .resizable(false)
            .default_width(240.0)
            .frame(
                egui::Frame::side_top_panel(&ctx.style())
                    .inner_margin(egui::Margin::symmetric(12.0, 12.0)),
            )
            .show(ctx, |ui| {
                let running = self.running.is_some();

                ui.label(egui::RichText::new("RUN A COMMAND").small().color(SUBTLE));
                ui.add_space(4.0);

                egui::ComboBox::from_id_salt("selected_command")
                    .width(ui.available_width())
                    .selected_text(COMMANDS[self.selected_command].label)
                    .show_ui(ui, |ui| {
                        for (index, command) in COMMANDS.iter().enumerate() {
                            ui.selectable_value(&mut self.selected_command, index, command.label);
                        }
                    });

                ui.small(COMMANDS[self.selected_command].description);
                ui.add_space(6.0);

                ui.add(
                    egui::TextEdit::singleline(&mut self.extra_args)
                        .hint_text("Extra arguments")
                        .desired_width(f32::INFINITY),
                );
                ui.add_space(6.0);

                ui.vertical_centered_justified(|ui| {
                    if ui
                        .add_enabled(
                            !running,
                            egui::Button::new(egui::RichText::new("Run").strong())
                                .fill(ACCENT.linear_multiply(0.25)),
                        )
                        .clicked()
                    {
                        self.run_selected_command();
                    }

                    if ui.add_enabled(running, egui::Button::new("Stop")).clicked() {
                        if let Some(process) = &self.running {
                            let _ = process.tx.send(ProcessInput::Stop);
                        }
                    }
                });

                ui.add_space(10.0);
                ui.separator();

                egui::ScrollArea::vertical().show(ui, |ui| {
                    for category in CATEGORIES {
                        ui.add_space(8.0);
                        ui.label(
                            egui::RichText::new(category.to_uppercase())
                                .small()
                                .color(SUBTLE),
                        );
                        ui.add_space(2.0);

                        for (index, command) in COMMANDS.iter().enumerate() {
                            if command.category != *category {
                                continue;
                            }

                            ui.vertical_centered_justified(|ui| {
                                if ui
                                    .add_enabled(!running, egui::Button::new(command.label))
                                    .on_hover_text(command.description)
                                    .clicked()
                                {
                                    self.selected_command = index;
                                    self.extra_args.clear();
                                    self.run_selected_command();
                                }
                            });
                        }
                    }
                });
            });

        egui::CentralPanel::default()
            .frame(
                egui::Frame::central_panel(&ctx.style())
                    .inner_margin(egui::Margin::symmetric(12.0, 10.0)),
            )
            .show(ctx, |ui| {
                let input_height = 34.0;
                let output_height = (ui.available_height() - input_height).max(120.0);

                egui::Frame::none()
                    .fill(egui::Color32::from_rgb(16, 18, 24))
                    .rounding(egui::Rounding::same(6.0))
                    .inner_margin(egui::Margin::same(8.0))
                    .show(ui, |ui| {
                        ui.set_min_height(output_height);
                        ui.set_max_height(output_height);
                        egui::ScrollArea::vertical()
                            .stick_to_bottom(true)
                            .auto_shrink([false, false])
                            .show(ui, |ui| {
                                ui.add(
                                    egui::TextEdit::multiline(&mut self.output)
                                        .font(egui::TextStyle::Monospace)
                                        .frame(false)
                                        .lock_focus(true)
                                        .desired_width(f32::INFINITY)
                                        .desired_rows(24),
                                );
                            });
                    });

                ui.add_space(6.0);
                ui.horizontal(|ui| {
                    let send_width = 60.0;
                    let response = ui.add_enabled(
                        self.running.is_some(),
                        egui::TextEdit::singleline(&mut self.input)
                            .hint_text("Send input to the running command")
                            .desired_width(ui.available_width() - send_width - 8.0),
                    );

                    let send = ui
                        .add_enabled(self.running.is_some(), egui::Button::new("Send"))
                        .clicked()
                        || (response.lost_focus()
                            && ui.input(|input| input.key_pressed(egui::Key::Enter)));

                    if send {
                        self.send_input();
                    }
                });
            });
    }
}

impl NexosManagerApp {
    fn collect_process_events(&mut self, ctx: &egui::Context) {
        let Some(process) = &self.running else {
            return;
        };

        let mut finished = None;
        while let Ok(event) = process.rx.try_recv() {
            match event {
                ProcessEvent::Output(output) => self.output.push_str(&output),
                ProcessEvent::Finished(status) => {
                    finished = Some(status);
                }
            }
        }

        if let Some(status) = finished {
            self.last_status = status;
            self.running = None;
        }

        ctx.request_repaint();
    }

    fn open_config(&mut self) {
        let Some(root) = &self.config_root else {
            self.last_status = "No config directory found.".to_string();
            return;
        };

        let path = root.path.to_string_lossy().to_string();
        self.start_pty_command(
            "Open Config".to_string(),
            "sh",
            vec![
                "-lc".to_string(),
                "exec ${VISUAL:-${EDITOR:-xdg-open}} \"$1\"".to_string(),
                "nexos-manager-open".to_string(),
                path,
            ],
        );
    }

    fn run_selected_command(&mut self) {
        let spec = COMMANDS[self.selected_command];
        let mut args = spec
            .args
            .iter()
            .map(|arg| (*arg).to_string())
            .collect::<Vec<_>>();

        match shlex::split(&self.extra_args) {
            Some(extra_args) => args.extend(extra_args),
            None => {
                self.last_status = "Could not parse arguments.".to_string();
                return;
            }
        }

        self.start_pty_command(format!("nex {}", args.join(" ")), "nex", args);
    }

    fn send_input(&mut self) {
        let Some(process) = &self.running else {
            return;
        };

        let mut input = std::mem::take(&mut self.input);
        input.push('\n');
        let _ = process.tx.send(ProcessInput::Text(input));
    }

    fn start_pty_command(&mut self, title: String, program: &str, args: Vec<String>) {
        if self.running.is_some() {
            self.last_status = "A command is already running.".to_string();
            return;
        }

        let (event_tx, event_rx) = mpsc::channel();
        let (input_tx, input_rx) = mpsc::channel();
        let program = program.to_string();
        let display_program = program.clone();
        let display_args = args.join(" ");
        let config_root = self.config_root.clone();
        let title_for_thread = title.clone();

        thread::spawn(move || {
            if let Err(error) = run_pty_command(
                &title_for_thread,
                &program,
                &args,
                config_root,
                event_tx.clone(),
                input_rx,
            ) {
                let _ = event_tx.send(ProcessEvent::Finished(error));
            }
        });

        self.output
            .push_str(&format!("\n$ {display_program} {display_args}\n"));
        self.last_status = format!("Started {title}");
        self.running = Some(RunningProcess {
            title,
            rx: event_rx,
            tx: input_tx,
        });
    }
}

fn run_pty_command(
    title: &str,
    program: &str,
    args: &[String],
    config_root: Option<ConfigRoot>,
    event_tx: Sender<ProcessEvent>,
    input_rx: Receiver<ProcessInput>,
) -> Result<(), String> {
    let pty_system = native_pty_system();
    let pair = pty_system
        .openpty(PtySize {
            rows: 30,
            cols: 120,
            pixel_width: 0,
            pixel_height: 0,
        })
        .map_err(|error| format!("failed to open pty: {error}"))?;

    let mut command = CommandBuilder::new(program);
    command.args(args);

    if let Some(root) = &config_root {
        command.cwd(&root.path);
        command.env("NEX_FLAKE", root.path.to_string_lossy().as_ref());
        command.env("NEXOS_MANAGER_CONFIG", root.path.to_string_lossy().as_ref());
    }

    let mut child = pair
        .slave
        .spawn_command(command)
        .map_err(|error| format!("failed to spawn {program}: {error}"))?;
    let mut reader = pair
        .master
        .try_clone_reader()
        .map_err(|error| format!("failed to open pty reader: {error}"))?;
    let mut writer = pair
        .master
        .take_writer()
        .map_err(|error| format!("failed to open pty writer: {error}"))?;

    let input_thread = thread::spawn(move || {
        while let Ok(input) = input_rx.recv() {
            match input {
                ProcessInput::Text(input) => {
                    if writer.write_all(input.as_bytes()).is_err() {
                        break;
                    }
                    let _ = writer.flush();
                }
                ProcessInput::Stop => {
                    if writer.write_all(&[3]).is_err() {
                        break;
                    }
                    let _ = writer.flush();
                }
            }
        }
    });

    let mut buffer = [0_u8; 4096];
    loop {
        match reader.read(&mut buffer) {
            Ok(0) => break,
            Ok(count) => {
                let output = String::from_utf8_lossy(&buffer[..count]).to_string();
                let _ = event_tx.send(ProcessEvent::Output(output));
            }
            Err(_) => break,
        }
    }

    let status = child
        .wait()
        .map(|status| format!("{title} exited with {status}"))
        .unwrap_or_else(|error| format!("{title} exited; status unavailable: {error}"));

    let _ = input_thread.join();
    let _ = event_tx.send(ProcessEvent::Finished(status));
    Ok(())
}

fn resolve_config_root() -> Option<ConfigRoot> {
    if let Ok(path) = env::var("NEX_FLAKE") {
        let path = PathBuf::from(path);
        if path.is_dir() {
            return Some(ConfigRoot {
                path,
                source: "NEX_FLAKE",
            });
        }
    }

    for (path, source) in [("/etc/nexos", "/etc/nexos"), ("/etc/nixos", "/etc/nixos")] {
        let path = PathBuf::from(path);
        if path.is_dir() {
            return Some(ConfigRoot { path, source });
        }
    }

    if let Some(path) = resolve_nh_flake() {
        return Some(ConfigRoot { path, source: "nh" });
    }

    None
}

fn resolve_nh_flake() -> Option<PathBuf> {
    let home = env::var_os("HOME").map(PathBuf::from)?;
    let candidates = [
        home.join(".config/nh/nh.toml"),
        home.join(".config/nh/config.toml"),
        PathBuf::from("/etc/nh/nh.toml"),
        PathBuf::from("/etc/nh/config.toml"),
    ];

    for candidate in candidates {
        let Ok(contents) = fs::read_to_string(candidate) else {
            continue;
        };

        for line in contents.lines() {
            let line = line.trim();
            if !line.starts_with("flake") {
                continue;
            }

            let Some((_, value)) = line.split_once('=') else {
                continue;
            };

            let value = value.trim().trim_matches('"');
            let path = expand_home(value);
            if path.is_dir() {
                return Some(path);
            }
        }
    }

    None
}

fn expand_home(path: &str) -> PathBuf {
    if let Some(rest) = path.strip_prefix("~/") {
        if let Some(home) = env::var_os("HOME") {
            return Path::new(&home).join(rest);
        }
    }

    PathBuf::from(path)
}

fn apply_style(ctx: &egui::Context) {
    ctx.set_visuals(egui::Visuals::dark());
    ctx.style_mut(|style| {
        style.spacing.item_spacing = egui::vec2(8.0, 6.0);
        style.spacing.button_padding = egui::vec2(10.0, 5.0);
        style.visuals.widgets.inactive.rounding = egui::Rounding::same(5.0);
        style.visuals.widgets.hovered.rounding = egui::Rounding::same(5.0);
        style.visuals.widgets.active.rounding = egui::Rounding::same(5.0);
        style.visuals.selection.bg_fill = ACCENT.linear_multiply(0.35);
        style.visuals.hyperlink_color = ACCENT;
    });
}

fn main() -> eframe::Result<()> {
    let options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_app_id("nexos-manager")
            .with_title("Nexos Manager")
            .with_inner_size([1000.0, 660.0])
            .with_min_inner_size([760.0, 520.0]),
        ..Default::default()
    };

    eframe::run_native(
        "Nexos Manager",
        options,
        Box::new(|cc| {
            apply_style(&cc.egui_ctx);
            Ok(Box::<NexosManagerApp>::default())
        }),
    )
}
