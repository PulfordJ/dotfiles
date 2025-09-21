{ config, pkgs, userdata, ... }:

{
  # YubiKey and U2F support packages
  environment.systemPackages = with pkgs; [
    pam_u2f
    yubikey-manager
    yubico-pam
    libfido2  # Provides pamu2fcfg utility
  ];

  # Add user to pcscd group for YubiKey access
  users.users.${userdata.username}.extraGroups = [ "pcscd" ];

  # PAM U2F configuration for YubiKey Bio
  security.pam.u2f = {
    enable = true;
    control = "sufficient";  # Allow fallback to password if U2F fails
    settings = {
      cue = true;
      # Use /etc/u2f_mappings as the auth file
      authfile = "/etc/u2f_mappings";
      # For YubiKey Bio: try fingerprint first, then PIN
      userverification = 1;
      pinverification = 0;
      # Enable debug logging for troubleshooting
      debug = true;
    };
  };

  # Enable U2F authentication for various PAM services
  security.pam.services.greetd.u2fAuth = true;
  security.pam.services.hyprlock.u2fAuth = true;
  security.pam.services.login.u2fAuth = true;
  security.pam.services.sudo.u2fAuth = true;

  # Enable PC/SC daemon for smart card support (required for YubiKey)
  services.pcscd.enable = true;

  # Polkit rules for PC/SC access
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
        if (action.id == "org.debian.pcsc-lite.access_pcsc" &&
            subject.isInGroup("pcscd")) {
            return polkit.Result.YES;
        }
    });
  '';

  # YubiKey udev rules for proper access
  services.udev.extraRules = ''
    # YubiKey 5 series
    SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0407", TAG+="uaccess", GROUP="pcscd", MODE="0664"
    # YubiKey Bio series
    SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0402", TAG+="uaccess", GROUP="pcscd", MODE="0664"
    SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0403", TAG+="uaccess", GROUP="pcscd", MODE="0664"
    # Generic YubiKey FIDO
    SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0120", TAG+="uaccess", GROUP="pcscd", MODE="0664"
    # HID interface for FIDO2
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1050", TAG+="uaccess", GROUP="pcscd", MODE="0664"
  '';
}