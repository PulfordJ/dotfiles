{
  lib,
  config,
  pkgs,
  project_root,
  inputs,
  userdata,
  ...
}: let
  package_config = import "${project_root}/macbook/home-manager/packages.nix" {
    project_root = project_root;
    pkgs = pkgs;
    inputs = inputs;
  };
in {
  age.identityPaths = ["/Users/john/newssh/id_ed25519"];
  age.secrets.secret1 = {
    file = ./secret1.age;
    owner = userdata.username;
  };
}
