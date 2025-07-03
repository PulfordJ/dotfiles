{
  lib,
  config,
  pkgs,
  project_root,
  inputs,
  userdata,
  ...
}: let
  package_config = import "${project_root}/nix/home-manager/packages.nix" {
    project_root = project_root;
    pkgs = pkgs;
    inputs = inputs;
  };
in 
{
  age.secrets.secret1.file = ./secret1.age;
  age.secrets.secret1.owner = userdata.username;
  age.identityPaths = ["/root/.ssh/id_ed25519"];
}
