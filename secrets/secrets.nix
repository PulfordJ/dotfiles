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
  age.identityPaths = ["/root/.ssh/id_ed25519"];
  age.rekey = {
    # Obtain this using `ssh-keyscan` or by looking it up in your ~/.ssh/known_hosts
    hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKREhtXi5NvZpmJFpA1RrytcxE3zih1oOU3CXUU4hArU your_email@example.com";
    # The path to the master identity used for decryption. See the option's description for more information.
    #masterIdentities = [ ./your-yubikey-identity.pub ];
    masterIdentities = [ "/root/.ssh/id_ed25519" ]; # External master key
    #masterIdentities = [
    #  # It is possible to specify an identity using the following alternate syntax,
    #  # this can be used to avoid unecessary prompts during encryption.
    #  {
    #    identity = "/home/myuser/master-key.age"; # Password protected external master key
    #    pubkey = "age1qyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqs3290gq"; # Specify the public key explicitly
    #  }
    #];
    storageMode = "local";
    # Choose a directory to store the rekeyed secrets for this host.
    # This cannot be shared with other hosts. Please refer to this path
    # from your flake's root directory and not by a direct path literal like ./secrets
    localStorageDir = ./. + "/rekeyed";
  };
  age.secrets.secret1 = {
    rekeyFile = ./secret1.age;
    owner = userdata.username;
  };
}

#let
#  user1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKREhtXi5NvZpmJFpA1RrytcxE3zih1oOU3CXUU4hArU your_email@example.com";
#  users = [ user1];
#
#  system1 = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILG8BLyLVHjRmWIqJLltfQWNgmrIWAEofJaUja4jN4cp root@nixos"];
#  systems = [system1];
#in
#{
#  "secret1.age".publicKeys = users ++ systems;
#}
