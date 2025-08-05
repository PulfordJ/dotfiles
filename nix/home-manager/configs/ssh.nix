{...}: {
  programs.ssh = {
    enable = true;
    forwardAgent = true;
    extraConfig = ''
      Host *
        IdentityFile /run/agenix/secret1
        IdentitiesOnly yes
    '';
  };
}