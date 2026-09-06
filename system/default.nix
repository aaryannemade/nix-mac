{ ... }:

{
  # Generic system policy. Anything specific to this particular machine's
  # hardware lives in hosts/peach/ instead.
  imports = [
    ./bootloader.nix
    ./display.nix
    ./fonts.nix
    ./garbage-collection.nix
    ./network.nix
    ./shell.nix
    ./sound.nix
    ./unfree.nix
    ./users.nix
  ];
}
