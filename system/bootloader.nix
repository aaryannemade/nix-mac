{ ... }:

{
  # systemd-boot rather than the GRUB setup on nix-desktop: Apple's EFI
  # implementation needs a blessed loader, and GRUB's efiSupport path is
  # unreliable on 2015-era Macs. systemd-boot installs cleanly to the ESP.
  boot.loader = {
    systemd-boot = {
      enable = true;
      # Apple's existing EFI partition is only 200 MB. The initrd is around
      # 80 MB, so retaining five boot generations fills it immediately.
      configurationLimit = 2;
    };

    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
  };
}
