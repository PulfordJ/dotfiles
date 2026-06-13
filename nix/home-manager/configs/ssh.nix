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
  };

  home.file = {
    ".ssh/id_ed25519.pub".source = "${project_root}/utilities/ssh/id_ed25519.pub";
  };
}