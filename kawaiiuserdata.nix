{
  username = "john";
  email = "johnpulford@gmail.com";
  name = "John Pulford";

  # Set to true to use a hermetic Neovim configuration
  # With this option enabled, you modify your Neovim configuration in the dotfiles repository, then run
  # nix rebuild to apply the changes.
  # Set this option to false allows direct editing of the Neovim configuration files in ~/.config/nvim,
  # making it's faster to iterate and test changes.
  hermeticNvimConfig = false;

  authorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKREhtXi5NvZpmJFpA1RrytcxE3zih1oOU3CXUU4hArU your_email@example.com"
  ];
}
