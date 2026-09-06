{ ... }:

{
  # ---- Wi-Fi / Bluetooth ----------------------------------------------------
  # MacBookPro11,5 ships a Broadcom BCM43602 (PCI 14e4:43ba). It is driven by
  # the *in-tree* `brcmfmac` module and needs nothing but redistributable
  # firmware out of linux-firmware, which is exactly what this option provides.
  #
  # Do not reach for the unfree `broadcom_sta` (wl) driver here. It claims
  # BCM4360 and older and does not support 43602 at all, so loading it produces
  # no wireless rather than better wireless. For reference, nixpkgs' own
  # hardware/network/broadcom-43xx.nix is literally just the line below.
  #
  # The same option also covers AMD GPU microcode and Intel CPU microcode.
  # nixos-hardware's 11-5 profile sets it with mkDefault; stated explicitly
  # here so the dependency is visible rather than inherited invisibly.
  hardware.enableRedistributableFirmware = true;

  # cfg80211 otherwise starts in the world regulatory domain (country 00),
  # where 5 GHz scanning is passive-only. Setting India explicitly makes the
  # BCM43602 actively scan the locally permitted 5 GHz channels; without it,
  # the `vite` network was not discoverable. This is the persistent equivalent
  # of the successfully tested `iw reg set IN` command.
  boot.extraModprobeConfig = ''
    options cfg80211 ieee80211_regdom=IN
  '';

  hardware.bluetooth.enable = true;

  # ---- Webcam ---------------------------------------------------------------
  # facetimehd is an out-of-tree kernel module. The firmware is extracted from
  # Apple's own OS X driver and is unfree, hence the allowlist entry below.
  #
  # nixos-hardware's apple profile only enables this when the *global*
  # nixpkgs.config.allowUnfree is set. This repo uses a scoped
  # allowUnfreePredicate instead (see system/unfree.nix), so that default
  # evaluates to false and the webcam has to be opted into here.
  #
  # The module also handles the known crash-on-suspend bug by unloading
  # facetimehd before sleep and modprobing it back on resume.
  hardware.facetimehd.enable = true;

  my.unfreePackages = [
    "facetimehd-firmware"
  ];
}
