# John Pulford's dotfiles repo


### Quick Update Commands
To update the system configuration, use one of these commands:

```bash
# For NixOS systems (can run as root initially, but long-term should run as user)
sudo nixos-rebuild switch --flake .#nixos --cores 0

# For specific host configurations
sudo nixos-rebuild switch --flake .#kawaiinixos --cores 0
sudo nixos-rebuild switch --flake .#rossnixos --cores 0
```

### Important Notes
- **Initial Setup**: You can run these commands as root during initial setup
- **Long-term Usage**: Should be run as the user specified in the relevant userdata file from their home directory (`~/dotfiles`)
- **Why User Directory**: Some configuration folders expect to be writable by the user, so running from the user's home directory ensures configs work properly

### WSL (standalone home-manager)

WSL runs Nix on top of an ordinary Ubuntu rootfs, so there is no NixOS or
nix-darwin layer. The `john@wsl` output is a standalone home-manager
configuration instead (`nix/hosts/wsl/home.nix`): user-level only, no `sudo`.

```bash
# Bootstrap (home-manager is not installed yet).
# -b backup renames any pre-existing file it would overwrite to <name>.backup
nix run github:nix-community/home-manager -- switch -b backup --flake ~/dotfiles#john@wsl

# Subsequent updates (home-manager installs itself into the profile)
home-manager switch --flake ~/dotfiles#john@wsl
```

Three manual steps Nix cannot do for you:

1. **Generate the `en_US.UTF-8` locale on the Ubuntu side.** Ubuntu's WSL image
   ships only `C`/`C.UTF-8`/`POSIX`. The host config sets `LANG=en_US.UTF-8`
   (home-manager's CLI panics parsing `C.UTF-8` as a language tag and exits 101,
   *after* activation has already succeeded) and provides a Nix
   `glibcLocales` via `LOCALE_ARCHIVE` for Nix-built binaries. Ubuntu's own glibc
   cannot read that archive — different glibc version — so Debian tooling such as
   `perl` warns until the locale also exists system-side:
   ```bash
   sudo locale-gen en_US.UTF-8
   ```
2. **Retire `~/.gitconfig`.** home-manager writes `~/.config/git/config`, and git
   reads *both*, with `~/.gitconfig` taking precedence — so an existing
   `~/.gitconfig` silently overrides the managed one. Its contents have been
   folded into `nix/hosts/wsl/home.nix`, so remove it once you have switched:
   `mv ~/.gitconfig ~/.gitconfig.pre-hm`
3. **Set zsh as the login shell.** Standalone home-manager cannot call `chsh`:
   ```bash
   command -v zsh | sudo tee -a /etc/shells
   chsh -s "$(command -v zsh)"
   ```

Notes specific to this host:
- Uses `wsl_packages` (headless core) rather than `default_packages`, which drops
  `texliveFull`, the Android SDK and `anki-bin`.
- `cudaSupport = false` is applied at the flake call site, keeping the CUDA
  `LD_LIBRARY_PATH` (and its multi-GB closure) out of the WSL profile while
  leaving the GPU desktop hosts unchanged.
- Claude Code is left to its own self-updating native installer; adding
  `pkgs.claude-code` here would shadow it and pin the version.
- `utilities/ssh/id_ed25519.pub` is **not** linked into `~/.ssh`. It is a
  placeholder key (its comment is still `your_email@example.com`, matching the
  stub in `userdata.authorizedKeys`) and does not correspond to any private key
  on this host, so linking it would clobber a working public key.

---
## ⚠️ OUTDATED CONTENT BELOW

**The information below is outdated. For current usage, see the updated instructions:**

## Screenshot

![alt text](./images/dwm-desktop.png "Screenshot")

## Nix

### NixOS

#### Bootstrap

To bootstrap NixOS with my dotfiles, follow these steps:
1. Clone the repository to ~/dotfiles under a username matching the username HOME directory defined in configuration.nix
2. Change the username defined configuration.nix

#### To update the system
1. Run `nix flake update ~/dotfiles`
2. Run `~/dotfiles/scripts/switch.sh`

#### Cleanup old generations
```bash
sudo nix-collect-garbage --delete-older-than 7d
sudo nix-store --optimise
```

### MacOS

Install XCode manually as this cannot currently be automated

then run these commands:
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer && sudo xcodebuild -runFirstLaunch
#### Bootstrap
To bootstrap nix on MacOS with my dotfiles, follow these steps:
1. Clone the repository to ~/dotfiles
2. Change the username defined configuration.nix
3. Install Nix on MacOS `sh <(curl -L https://nixos.org/nix/install)`
4. Run `nix flake update ~/dotfiles`
5. Run `nix --extra-experimental-features nix-command --extra-experimental-features flakes  run nix-darwin -- switch --flake ~/dotfiles#macbook-m1`

#### To update the system
After bootstrapping, you can update your system by running `~/dotfiles/scripts/switch.sh`
