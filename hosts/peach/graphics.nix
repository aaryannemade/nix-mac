{ pkgs, ... }:

{
  # MacBookPro11,5 has two GPUs sitting behind Apple's gmux multiplexer:
  #
  #   Intel Iris Pro 5200  - Haswell GT3e, driven by i915
  #   AMD Radeon R9 M370X  - PCI 1002:6821, "Venus XT"
  #
  # ---- AMD ------------------------------------------------------------------
  # Use the same kernel series as the graphical installer, where the panel is
  # known to work. NixOS 26.05's default 6.18 kernel bound the GPU but failed
  # Atomic Mode Setting and produced a permanently black internal display.
  # Kernel 7.2 selects amdgpu for this SI device without override parameters.
  boot.kernelPackages = pkgs.linuxPackages_latest.extend (_final: previous: {
    # Linux 7.2 removed vb2_ops.wait_prepare/wait_finish and stopped exposing
    # string functions through indirect includes. facetimehd 0.6.13 still uses
    # the old API; remove the now-unnecessary callbacks and include string.h.
    facetimehd = previous.facetimehd.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [ ./patches/facetimehd-linux-7.2.patch ];
    });
  });

  # ---- Intel ----------------------------------------------------------------
  # nixos-hardware's 11-5 module imports common/cpu/intel, the *generic* Intel
  # profile, which leaves hardware.intelgpu.vaapiDriver at null and so installs
  # both intel-vaapi-driver and intel-media-driver. intel-media-driver only
  # supports Broadwell and newer; this machine is Haswell (Crystal Well
  # i7-4870HQ). The 11-4 module gets this right by importing the haswell
  # profile, 11-5 does not, so pin the correct VA-API driver here.
  hardware.intelgpu.vaapiDriver = "intel-vaapi-driver";

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Let Xorg and KWin probe the GPUs rather than forcing an Xorg Screen section.
  # NOTE: which GPU actually drives the internal panel is decided by Apple's
  # EFI before Linux starts, and on this model that is normally the AMD part.
  # vga_switcheroo can hand the panel over to the Intel GPU at runtime
  # (/sys/kernel/debug/vgaswitcheroo/switch), which is a large battery win, but
  # doing it reliably at boot needs an apple-set-os EFI shim in the ESP. Not
  # set up here.
}
