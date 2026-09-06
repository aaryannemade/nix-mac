{ ... }:

{
  # systemd-boot rather than the GRUB setup on nix-desktop: Apple's EFI
  # implementation needs a blessed loader, and GRUB's efiSupport path is
  # unreliable on 2015-era Macs. systemd-boot installs cleanly to the ESP.
  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 5;
    };

    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
  };
}
