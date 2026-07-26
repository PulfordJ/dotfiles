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
  # no agenix. Everything below has to be self-contained at the user level.
  #
  # Deliberately omitted relative to the desktop hosts:
  #   - hyprland/waybar/mako/tofi/hyprlock, firefox, xremap, gammastep, stylix
  #     and the gtk/qt/xdg-portal wiring: there is no display server.
  #   - ssh.nix: it points identityFile at /run/agenix/secret1, which only the
  #     system-level agenix module creates.
  #   - vscode.nix: VS Code runs on the Windows side and reaches in over
  #     vscode-server, so the Linux-side package would be unused.
  imports = [
    "${project_root}/nix/home-manager/configs/zsh.nix"
    "${project_root}/nix/home-manager/configs/nvim.nix"
    "${project_root}/nix/home-manager/configs/tmux.nix"
  ];

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
}
