{
  description = "NixOS for MacBook Pro 15\" (Mid 2015, MacBookPro11,5)";

  inputs = {
    nixpkgs = {
      url = "nixpkgs/nixos-26.05";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # Upstream-maintained quirks for this exact machine: the XHC1 wakeup udev
    # rule that stops spurious resume-after-suspend, Intel GPU defaults, fstrim,
    # mbpfan, and the laptop TLP/power-profiles-daemon interlock.
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
      # nixos-hardware only uses its nixpkgs input for its own checks and
      # formatter; following ours keeps a second nixpkgs out of the lock file.
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      nixos-hardware,
      ...
    }:
    {
      nixosConfigurations = import ./hosts {
        inherit
          nixpkgs
          home-manager
          nixos-hardware
          inputs
          ;
      };

      formatter.x86_64-linux =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        in
        pkgs.writeShellApplication {
          name = "nixfmt-tree";
          runtimeInputs = [
            pkgs.nixfmt
            pkgs.findutils
          ];
          text = ''
            if [ "$#" -eq 0 ]; then
              set -- .
            fi
            find "$@" -type f -name '*.nix' -print0 | xargs -0 -r nixfmt
          '';
        };
    };
}
