{
  pkgs,
  config,
  lib,
  project_root,
  inputs,
  userdata,
  ...
}: let
  package_config = import "${project_root}/nix/home-manager/packages.nix" {
    pkgs = pkgs;
    inputs = inputs;
    project_root = project_root;
  };
  # Ubuntu's WSL image generates only the C/C.UTF-8/POSIX locales. home-manager's
  # CLI panics parsing `C.UTF-8` as a language tag (ParserError(InvalidLanguage)),
  # so `switch` exits 101 even after activation has succeeded. Ship a real UTF-8
  # locale rather than pointing LANG at one glibc cannot load. Only en_US is
  # built; the full glibcLocales is ~200MB.
  locales = pkgs.glibcLocales.override {
    allLocales = false;
    locales = ["en_US.UTF-8/UTF-8"];
  };
in {
  # WSL runs standalone home-manager on top of an ordinary Ubuntu rootfs, so
  # there is no system module layer here: no NixOS/nix-darwin configuration, and
  # no system agenix (secrets use agenix's home-manager module instead, below).
  # Everything below has to be self-contained at the user level.
  #
  # Deliberately omitted relative to the desktop hosts:
  #   - hyprland/waybar/mako/tofi/hyprlock, firefox, xremap, gammastep, stylix
  #     and the gtk/qt/xdg-portal wiring: there is no display server.
  #   - ssh.nix: it points identityFile at /run/agenix/secret1, which only the
  #     system-level agenix module creates. The agent-forwarding setup it
  #     provides is reproduced against this host's own keys further down.
  #   - vscode.nix: VS Code runs on the Windows side and reaches in over
  #     vscode-server, so the Linux-side package would be unused.
  imports = [
    "${project_root}/nix/home-manager/configs/zsh.nix"
    "${project_root}/nix/home-manager/configs/nvim.nix"
    "${project_root}/nix/home-manager/configs/tmux.nix"
    inputs.agenix.homeManagerModules.default
  ];

  # User-level agenix: decrypted by a systemd user service into
  # $XDG_RUNTIME_DIR/agenix at login, then symlinked to each `path`. The
  # secrets are encrypted to the master identity (secrets/secrets.nix), whose
  # private half is present on this host as the mum-osmc key.
  age.identityPaths = ["${config.home.homeDirectory}/.ssh/id_ed25519_mum-osmc"];
  age.secrets = {
    # Release signing key for the Weight Δ Android app; key.properties points
    # Gradle at the keystore and holds its passwords.
    weightdeltatracker-keystore = {
      file = "${project_root}/secrets/weightdeltatracker-release.jks.age";
      path = "${config.home.homeDirectory}/.android/weightdeltatracker-release.jks";
    };
    weightdeltatracker-key-properties = {
      file = "${project_root}/secrets/weightdeltatracker-key.properties.age";
      path = "${config.home.homeDirectory}/projects/weight_change_tracker/android/key.properties";
    };
  };

  home.username = userdata.username;
  home.homeDirectory = "/home/${userdata.username}";

  home.packages = package_config.wsl_packages ++ [locales];
  home.stateVersion = "23.11";

  home.sessionVariables = {
    EDITOR = "nvim";
    LOCALE_ARCHIVE = "${locales}/lib/locale/locale-archive";
    LANG = "en_US.UTF-8";
  };

  # A login zsh gets none of these otherwise. Nix's zsh does not read
  # /etc/profile, so /etc/profile.d/nix.sh - which is what puts the Nix profiles
  # on PATH for bash - never runs, leaving `nix` and `home-manager` unavailable
  # in a login shell. Ordered by precedence:
  #   ~/.local/bin  - matches the existing ~/.bashrc prepend. Required so the
  #                   self-updating Claude Code install wins over the older
  #                   npm-global copy at /usr/bin/claude.
  #   ~/.nix-profile/bin           - this home-manager generation.
  #   /nix/var/nix/profiles/default/bin - the daemon profile, where `nix` lives.
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.nix-profile/bin"
    "/nix/var/nix/profiles/default/bin"
  ];

  home.file = {
    # Claude Code reads its global instructions from $CLAUDE_CONFIG_DIR/CLAUDE.md,
    # defaulting to ~/.claude - not ~/.config/claude as the desktop hosts assume.
    ".claude/CLAUDE.md".source = "${project_root}/utilities/claude/CLAUDE.md";
    # Kimi Code reads its global instructions from ~/.agents/AGENTS.md (the
    # generic cross-tool location; ~/.kimi-code/AGENTS.md is the Kimi-specific
    # one). Same source file as Claude Code so they stay in sync.
    ".agents/AGENTS.md".source = "${project_root}/utilities/claude/CLAUDE.md";
    ".gemini/GEMINI.md".source = "${project_root}/utilities/gemini/GEMINI.md";
    ".config/starship.toml".source = "${project_root}/utilities/starship/starship.toml";
    ".config/tmuxinator".source = "${project_root}/utilities/tmuxinator";
    # NOTE: utilities/ssh/id_ed25519.pub is deliberately NOT linked here. It is a
    # placeholder (comment: your_email@example.com) and does not match this
    # host's ~/.ssh/id_ed25519, so linking it would replace a working public key
    # with one whose private half is not present.
    ".config/nvim".source =
      if userdata.hermeticNvimConfig
      then "${project_root}/utilities/nvim"
      else config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/utilities/nvim";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    userName = userdata.name;
    userEmail = userdata.email;
    extraConfig = {
      core = {
        editor = "nvim";
        # Checkouts under /mnt/c are shared with Windows tooling, which writes
        # CRLF; normalise on commit without rewriting working-tree endings.
        autocrlf = "input";
      };
      # Auth goes through the Ubuntu-side gh CLI. The empty string first resets
      # the inherited helper list, otherwise Nix git's system config stacks on
      # top of this one.
      "credential \"https://github.com\"" = {
        helper = ["" "!/usr/bin/gh auth git-credential"];
      };
      "credential \"https://gist.github.com\"" = {
        helper = ["" "!/usr/bin/gh auth git-credential"];
      };
    };
  };

  programs.bat = {
    enable = true;
  };
  programs.zoxide.enable = true;

  # SSH agent forwarding, so a session on media-center-pi can push that host's
  # dotfiles to GitHub with the key that never leaves this machine.
  #
  # macOS gets an agent for free from launchd, which is why the darwin build
  # only had to set ForwardAgent. WSL starts with no agent at all, so there was
  # nothing to forward: the three pieces below are the agent, the key inside it,
  # and the forwarding itself. systemd's user instance is available to run the
  # agent because /etc/wsl.conf sets systemd=true.
  services.ssh-agent.enable = true;

  # The agent starts empty. Forwarding only exposes keys that are already
  # loaded, and nothing on this host would otherwise load one until an outbound
  # ssh happened to use it - which is both too late and the wrong key. Seed it
  # at login instead. ~/.ssh/id_ed25519 is the key GitHub knows (listed there as
  # "GitHub CLI") and it has no passphrase, so this needs no prompt.
  systemd.user.services.ssh-add-keys = {
    Unit = {
      Description = "Load SSH keys into the agent";
      After = ["ssh-agent.service"];
      Requires = ["ssh-agent.service"];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      Environment = "SSH_AUTH_SOCK=%t/${config.services.ssh-agent.socket}";
      ExecStart = "${lib.getExe' pkgs.openssh "ssh-add"} %h/.ssh/id_ed25519";
    };
    Install.WantedBy = ["default.target"];
  };

  programs.ssh = {
    enable = true;
    # Upstream's implicit `Host *` block is deprecated and warns; everything it
    # would set is either a default or spelled out below.
    enableDefaultConfig = false;
    matchBlocks = {
      # ForwardAgent is deliberately scoped to this one host rather than "*":
      # anything you forward the agent to can use these keys, against any
      # server, for as long as the connection is open.
      "media-center-pi" = {
        user = "pi";
        forwardAgent = true;
        identityFile = "~/.ssh/id_ed25519";
        identitiesOnly = true;
      };
      "mum-osmc" = {
        user = "osmc";
        hostname = "mum-osmc";
        identityFile = "~/.ssh/id_ed25519_mum-osmc";
        identitiesOnly = true;
      };
      # Carried over from the hand-written config this replaces. The module
      # always emits "*" last, so the blocks above win.
      "*" = {
        identityFile = "~/.ssh/id_ed25519_mum-osmc";
      };
    };
  };

  # WSL sessions frequently land in plain bash (the Ubuntu default, and what
  # tools like vscode-server spawn), while the shared configs only wire atuin
  # into zsh. Without this, every bash command evaporates on exit since Ubuntu's
  # stock .bashrc was never even writing ~/.bash_history. Letting home-manager
  # manage bash gives atuin a .bashrc to hook into; the settings themselves
  # (fuzzy search, compact UI) are inherited from configs/zsh.nix.
  programs.bash = {
    enable = true;
    historyControl = ["ignoredups" "ignorespace"];
    initExtra = ''
      # Ephemeral kimi-code install location; guard it so shells don't break
      # after /tmp is cleared.
      [ -d /tmp/kimi-clean/.kimi-code/bin ] && export PATH="/tmp/kimi-clean/.kimi-code/bin:$PATH"

      # services.ssh-agent exports SSH_AUTH_SOCK through hm-session-vars.sh,
      # which .zshenv sources unconditionally but bash only reaches via
      # .profile - i.e. login shells. A non-login bash (vscode-server's
      # terminals, `bash -c`) would otherwise see no agent at all.
      [ -z "$SSH_AUTH_SOCK" ] && [ -n "$XDG_RUNTIME_DIR" ] && export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/${config.services.ssh-agent.socket}"
    '';
  };

  # atuin captures bash history via bash-preexec (pulled in by the module).
  # enable/enableZshIntegration/settings come from configs/zsh.nix.
  programs.atuin.enableBashIntegration = true;
}
