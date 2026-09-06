{
  nixpkgs,
  home-manager,
  nixos-hardware,
  inputs,
  ...
}:

let
  hostname = "peach";
  username = "aaryan";
  homeDirectory = "/home/${username}";
in
{
  ${hostname} = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";

    specialArgs = {
      inherit
        inputs
        hostname
        username
        homeDirectory
        ;
    };

    modules = [
      ./peach/configuration.nix

      nixos-hardware.nixosModules.apple-macbook-pro-11-5

      home-manager.nixosModules.home-manager
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          users.${username} = import ../home.nix;
          backupFileExtension = "backup";

          extraSpecialArgs = {
            inherit
              inputs
              username
              homeDirectory
              ;
          };
        };
      }
    ];
  };
}
