{ hostname, ... }:

{
  imports = [
    ../../configuration.nix # Common config
    ./hardware-configuration.nix # Generated on the machine
    ./graphics.nix # Dual GPU: Iris Pro 5200 + Radeon R9 M370X
    ./peripherals.nix # Wi-Fi firmware, webcam
    ./power.nix # Power profiles, thermals, fan control
  ];

  time.timeZone = "Asia/Calcutta";

  # Touchpad.
  services.libinput.enable = true;

  programs.zsh.shellAliases = {
    nrs = "sudo nixos-rebuild switch --flake ~/nix-mac#${hostname}";
  };
}
