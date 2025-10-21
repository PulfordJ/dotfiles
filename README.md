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
