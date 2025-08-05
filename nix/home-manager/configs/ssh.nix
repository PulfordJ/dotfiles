{
  lib,
  config,
  userdata,
  project_root,
  ...
}: {
  programs.ssh = {
    enable = true;
    forwardAgent = true;
    extraConfig = ''
      Host *
        IdentityFile /run/agenix/secret1
        IdentitiesOnly yes
    '';
  };

  home.file = {
    ".ssh/id_ed25519.pub".source = "${project_root}/utilities/ssh/id_ed25519.pub";
  };
}