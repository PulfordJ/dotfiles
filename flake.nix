{
  description = "cunbidun's dotfiles";

  inputs = {
    nixpkgs-unstable = {url = "github:nixos/nixpkgs/nixos-unstable";};
    nix-darwin = {url = "github:LnL7/nix-darwin";};
    home-manager = {url = "github:nix-community/home-manager";};
    apple-fonts = {url = "github:Lyndeno/apple-fonts.nix";};
    nix-speedtest-module = {url = "github:PulfordJ/nix-speedtest-module";};
    claude-code.url = "github:sadjow/claude-code-nix";

    # +----------+
    # | Hyprland |
    # +----------+
    hyprland = {url = "github:hyprwm/Hyprland/?submodules=1";};
    hypridle = {url = "github:hyprwm/hypridle";};
    pyprland = {url = "github:hyprland-community/pyprland";};
    hyprland-contrib = {url = "github:hyprwm/contrib";};
    hyprcursor-phinger = {url = "github:jappie3/hyprcursor-phinger";};
    xremap-flake = {
      url = "github:xremap/nix-flake";
      inputs.hyprland.follows = "hyprland";
    };
    hyprfocus = {
      url = "github:cunbidun/hyprfocus";
      inputs.hyprland.follows = "hyprland";
    };
    Hyprspace = {
      url = "github:KZDKM/Hyprspace";
      inputs.hyprland.follows = "hyprland";
    };

    # +--------+
    # | Others |
    # +--------+
    yazi = {url = "github:sxyazi/yazi/v25.4.8";};
    stylix = {url = "github:nix-community/stylix";};
    spicetify-nix = {url = "github:Gerg-L/spicetify-nix";};

    mac-app-util.url = "github:hraban/mac-app-util";
    nur.url = "github:nix-community/nur";

    # +----------------+
    # | Neovim plugins |
    # +----------------+
    auto-dark-mode-nvim = {
      url = "github:f-person/auto-dark-mode.nvim";
      flake = false;
    };
    copilot-lua = {
      url = "github:zbirenbaum/copilot.lua";
      flake = false;
    };
    blink-copilot = {
      url = "github:fang2hou/blink-copilot";
      flake = false;
    };
    nix-monitored = {
      url = "github:ners/nix-monitored";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.agenix.url = "github:ryantm/agenix";
  inputs.agenix-rekey.url = "github:oddlama/agenix-rekey";
  inputs.disko.url = "github:nix-community/disko";
  # Make sure to override the nixpkgs version to follow your flake,
  # otherwise derivation paths can mismatch (when using storageMode = "derivation"),
  # resulting in the rekeyed secrets not being found!
  inputs.agenix-rekey.inputs.nixpkgs.follows = "nixpkgs-unstable";

  outputs = inputs @ {
    self,
    nixpkgs-unstable,
    nix-darwin,
    home-manager,
    agenix,
    agenix-rekey,
    flake-utils,
    claude-code,
    disko,
    ...
  }: let
    project_root = ./.;
    userdata = import ./userdata.nix;
    mkPkgs = system:
      import nixpkgs-unstable {
        inherit system;
        overlays = [
          inputs.nur.overlays.default
          (import "${project_root}/nix/overlays/firefox-addons.nix")
          (import "${project_root}/nix/overlays/vim-plugins.nix" inputs)
          agenix-rekey.overlays.default
          claude-code.overlays.default
        ];
        config.allowUnfree = true;
      };

    mkHomeManagerModule = configPath: {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        users.${userdata.username} = import configPath;
        extraSpecialArgs = {
          inherit project_root inputs;
          userdata = userdata;
        };
      };
    };

    mkDarwinSystem = {
      system,
      stateVersionNum,
    }:
      nix-darwin.lib.darwinSystem {
        pkgs = mkPkgs system;
        specialArgs = {
          inherit inputs userdata;
          inherit (inputs) nix-speedtest-module;
          stateVersion = stateVersionNum;
        };
        modules = [
          inputs.mac-app-util.darwinModules.default
          ./nix/hosts/macbook/configuration.nix
          inputs.nix-speedtest-module.darwinModules.default
          home-manager.darwinModules.home-manager
          (mkHomeManagerModule "${project_root}/nix/hosts/macbook/home.nix")
          agenix.darwinModules.default
          #agenix-rekey.nixosModules.default
          ./secrets/macsecrets.nix
        ];
      };

    mkNixosHost = {
      system,
      hostPath,
      homePath,
    }:
      nixpkgs-unstable.lib.nixosSystem {
        pkgs = mkPkgs system;
        specialArgs = {
          inherit inputs userdata;
        };
        modules = [
          hostPath
          home-manager.nixosModules.home-manager
          (mkHomeManagerModule homePath)
          agenix.nixosModules.default
          agenix-rekey.nixosModules.default
          ./secrets/secrets.nix
        ];
      };
  in {
    # -----------------------#
    # macbook configurations #
    # -----------------------#
    darwinConfigurations = {
      "macbook-m1" = mkDarwinSystem {
        system = "aarch64-darwin";
        stateVersionNum = 4;
      };
      "macbook-intel" = mkDarwinSystem {
        system = "x86_64-darwin";
        stateVersionNum = 5;
      };
    };

    # -----------------------#
    #  nixos configurations  #
    # -----------------------#
    nixosConfigurations = {
      nixos = nixpkgs-unstable.lib.nixosSystem {
        pkgs = mkPkgs "x86_64-linux";
        specialArgs = {
          inherit inputs userdata;
        };
        modules = [
          ./nix/hosts/nixos/configuration.nix
          home-manager.nixosModules.home-manager
          (mkHomeManagerModule "${project_root}/nix/hosts/nixos/home.nix")
          agenix.nixosModules.default
          agenix-rekey.nixosModules.default
          ./secrets/secrets.nix
        ];
      };
      kawaiinixos = nixpkgs-unstable.lib.nixosSystem {
        pkgs = mkPkgs "x86_64-linux";
        specialArgs = {
          inherit inputs userdata;
        };
        modules = [
          ./nix/hosts/nixos/configuration.nix
          ./nix/hosts/nixos/disko.nix
          disko.nixosModules.disko
          home-manager.nixosModules.home-manager
          (mkHomeManagerModule "${project_root}/nix/hosts/nixos/home.nix")
          agenix.nixosModules.default
          agenix-rekey.nixosModules.default
          ./secrets/secrets.nix
        ];
      };
    };

    # ------------------------#
    #   devShell for nixos    #
    # ------------------------#
    devShells = {
      x86_64-linux = let
        pkgs = mkPkgs "x86_64-linux";
      in {
        default = pkgs.mkShell {
          packages = [pkgs.agenix-rekey];
        };
      };
    };
    # Expose the necessary information in your flake so agenix-rekey
    # knows where it has to look for secrets and paths.
    #
    # Make sure that the pkgs passed here comes from the same nixpkgs version as
    # the pkgs used on your hosts in `nixosConfigurations`, otherwise the rekeyed
    # derivations will not be found!
    agenix-rekey = agenix-rekey.configure {
      userFlake = self;
      nixosConfigurations = self.nixosConfigurations;
      # Example for colmena:
      # nixosConfigurations = ((colmena.lib.makeHive self.colmena).introspect (x: x)).nodes;
    };
  };
}
