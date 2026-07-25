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

  home.packages = package_config.wsl_packages;
  home.stateVersion = "23.11";

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  home.file = {
    # Claude Code reads its global instructions from $CLAUDE_CONFIG_DIR/CLAUDE.md,
    # defaulting to ~/.claude - not ~/.config/claude as the desktop hosts assume.
    ".claude/CLAUDE.md".source = "${project_root}/utilities/claude/CLAUDE.md";
    ".gemini/GEMINI.md".source = "${project_root}/utilities/gemini/GEMINI.md";
    ".config/starship.toml".source = "${project_root}/utilities/starship/starship.toml";
    ".config/tmuxinator".source = "${project_root}/utilities/tmuxinator";
    ".ssh/id_ed25519.pub".source = "${project_root}/utilities/ssh/id_ed25519.pub";
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
      safe = {
        directory = [
          "/mnt/c/Users/johnp/Projects/netwealthanalysius/transaction_dataframe_standard"
          "/mnt/c/Users/johnp/Projects/netwealthanalysius/userdata/john"
        ];
      };
    };
  };

  programs.bat = {
    enable = true;
  };
  programs.zoxide.enable = true;
}
