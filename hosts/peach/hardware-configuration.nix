# ─────────────────────────────────────────────────────────────────────────────
# PLACEHOLDER — REPLACE THIS FILE ON THE MACHINE.
#
# On the target MacBook, after partitioning and mounting, run:
#
#   nixos-generate-config --root /mnt --show-hardware-config \
#     > /mnt/home/aaryan/nix-mac/hosts/peach/hardware-configuration.nix
#
# The values below are a best guess for a MacBookPro11,5 (15", Mid 2015 —
# Haswell "Crystal Well" i7-4870HQ, not Broadwell; the quad-core 15" skipped
# that generation). They will work as-is ONLY if the install partitions are
# labelled `nixos` (root, ext4) and `boot` (ESP, vfat). See README.md.
# ─────────────────────────────────────────────────────────────────────────────
{
  config,
  lib,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usb_storage"
    "usbhid"
    "sd_mod"
    "sdhci_pci"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
