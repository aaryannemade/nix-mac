{ ... }:

{
  # home-manager modules. Each subdirectory is a group with its own default.nix.
  imports = [
    ./browsers
    ./desktop
    ./shell
  ];
}
