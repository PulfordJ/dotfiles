{
  lib,
  config,
  userdata,
  project_root,
  ...
}: {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks."*" = {
      forwardAgent = true;
      identityFile = "/run/agenix/secret1";
      identitiesOnly = true;
    };
    matchBlocks."beastpc" = {
      hostname = "beastpc";
      user = "john";
      port = 2222;
      extraOptions = {
        ConnectTimeout = "5";
        ConnectionAttempts = "60";
      };
    };
    matchBlocks."media-center-pi" = {
      hostname = "media-center-pi";
      user = "pi";
      extraOptions = {
        ConnectTimeout = "5";
        ConnectionAttempts = "60";
      };
    };
  };

  home.file = {
    ".ssh/id_ed25519.pub".source = "${project_root}/utilities/ssh/id_ed25519.pub";
  };
}