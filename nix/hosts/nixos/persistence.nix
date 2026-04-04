{
  config,
  lib,
  userdata,
  ...
}: {
  # Enable impermanence
  environment.persistence."/persist" = {
    hideMounts = true;

    directories = [
      "/var/log"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/var/lib/NetworkManager"
      "/var/lib/tailscale"
      "/var/lib/bluetooth"
      "/var/cache"
      "/var/tmp"
      "/etc/nixos"
      "/etc/NetworkManager/system-connections"
    ];

    files = [
      "/etc/machine-id"
    ];

    users.${userdata.username} = {
      directories = [
        # Shell history and configuration
        ".local/share/atuin"
        ".local/share/zsh"

        # Application data
        ".config"
        ".local/share"
        ".local/state"
        ".cache"

        # SSH and keys
        ".ssh"
        ".gnupg"

        # Development
        ".cargo"
        ".rustup"
        "note"
        "competitive_programming"

        # Docker and containers
        ".docker"

        # Browser data
        ".config/BraveSoftware"

        # Other important directories
        "Desktop"
        "Documents"
        "Downloads"
        "Pictures"
        "Videos"
        "Music"
      ];

      files = [
        # Shell history files
        ".zsh_history"
        ".bash_history"
      ];
    };
  };

  # Create the persistent directory structure
  systemd.tmpfiles.rules = [
    "d /persist 0755 root root -"
    "d /persist/home 0755 root root -"
    "d /persist/home/${userdata.username} 0755 ${userdata.username} users -"
  ];

  # Bind mount the home directory
  fileSystems."/home/${userdata.username}" = {
    device = "/persist/home/${userdata.username}";
    fsType = "none";
    options = [ "bind" ];
    neededForBoot = true;
  };
}