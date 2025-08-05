# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository using Nix flakes for declarative system configuration across both NixOS and macOS (via nix-darwin). The repository supports multiple hosts with shared home-manager configurations for consistent user environments.

## Architecture

### Core Structure
- **`flake.nix`**: Main entry point defining inputs, outputs, and system configurations
- **`userdata.nix`**: User-specific configuration (username, email, SSH keys, preferences)
- **`nix/hosts/`**: Host-specific configurations for different machines
  - `macbook/`: macOS configuration using nix-darwin
  - `nixos/`: NixOS configuration for Linux systems
- **`nix/home-manager/`**: User environment configuration shared across hosts
  - `packages.nix`: Package definitions split by platform (default, linux, mac)
  - `configs/`: Application-specific configurations (nvim, zsh, tmux, etc.)
  - `scripts.nix`: Custom shell scripts and utilities

### Key Features
- **Hermetic Neovim Configuration**: Toggle between system-managed (`hermeticNvimConfig = true`) and user-editable (`hermeticNvimConfig = false`) Neovim configs in `userdata.nix`
- **Secrets Management**: Uses agenix and agenix-rekey for encrypted secrets handling
- **Hyprland Desktop**: Full Wayland desktop environment configuration for NixOS
- **Cross-platform Package Management**: Separated package lists for Linux/macOS with shared defaults

## Common Commands

### System Management
```bash
# Update system configuration (primary command)
~/dotfiles/scripts/switch.sh <profile_name>

# Available profiles: 'macbook-m1', 'macbook-intel', 'nixos'
# Examples:
~/dotfiles/scripts/switch.sh macbook-m1
~/dotfiles/scripts/switch.sh nixos

# Switch without auto-committing changes
~/dotfiles/scripts/switch.sh --no-commit macbook-m1

# Switch with custom commit message
~/dotfiles/scripts/switch.sh --commit-message "Update vim config" nixos
```

### Flake Operations
```bash
# Update flake inputs
nix flake update ~/dotfiles

# Build without switching
nix build ~/dotfiles#darwinConfigurations.macbook-m1.system  # macOS
nix build ~/dotfiles#nixosConfigurations.nixos.config.system.build.toplevel  # NixOS

# Direct rebuild (alternative to switch.sh)
darwin-rebuild switch --flake ~/dotfiles#macbook-m1  # macOS
nixos-rebuild switch --flake ~/dotfiles#nixos        # NixOS
```

### Maintenance
```bash
# Cleanup old generations (NixOS)
sudo nix-collect-garbage --delete-older-than 7d
sudo nix-store --optimise

# Delete old generations script
~/dotfiles/scripts/delete_old_generation.sh
```

## Configuration Guidelines

### Adding New Packages
- Edit `nix/home-manager/packages.nix`
- Add to appropriate list: `default_packages` (cross-platform), `linux_packages`, or `mac_packages`
- Run `~/dotfiles/scripts/switch.sh <profile>` to apply

### Neovim Configuration
- **Hermetic mode** (`hermeticNvimConfig = true`): Edit `utilities/nvim/` files, rebuild system
- **Direct mode** (`hermeticNvimConfig = false`): Edit `~/.config/nvim/` directly for faster iteration

### Adding New Hosts
1. Create host directory in `nix/hosts/<hostname>/`
2. Add `configuration.nix` and `home.nix`
3. Define new configuration in `flake.nix` outputs
4. Update `scripts/switch.sh` profile validation

### User Data Changes
- Modify `userdata.nix` for username, email, SSH keys, or feature toggles
- Changes require system rebuild to take effect

## Development Environment

The repository includes a development shell with agenix-rekey for secret management:
```bash
nix develop  # Available on Linux systems
```

## Important Notes

- The switch script expects dotfiles to be at `~/dotfiles` (enforced for safety)
- Hardware configuration auto-sync on NixOS (copies from `/etc/nixos/hardware-configuration.nix`)
- Commits are automatically created on successful switches (unless `--no-commit` specified)
- Secrets are encrypted with agenix and stored in `secrets/` directory
- macOS requires manual Homebrew installation before first run
- XCode must be manually installed on macOS before running configurations