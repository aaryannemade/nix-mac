{ ... }:

{
  # MacBookPro11,5 has two GPUs sitting behind Apple's gmux multiplexer:
  #
  #   Intel Iris Pro 5200  - Haswell GT3e, driven by i915
  #   AMD Radeon R9 M370X  - PCI 1002:6821, "Venus XT"
  #
  # ---- AMD ------------------------------------------------------------------
  # "Venus XT" is a Cape Verde rebrand, which makes it GCN 1.0, a.k.a. Southern
  # Islands. The kernel binds SI parts to the legacy `radeon` driver by default
  # and `amdgpu` refuses to claim them unless explicitly told to, so both halves
  # of the handover have to be spelled out: radeon lets go, amdgpu picks up.
  #
  # amdgpu is what gets us Vulkan (radv, which only speaks to amdgpu) and
  # well-behaved atomic modesetting under Plasma 6 on Wayland. AMD still labels
  # SI support here "experimental", though it has been in tree for years.
  #
  # Recovery: if the machine ever fails to reach a display, delete these two
  # params. The kernel falls back to `radeon`, which loses Vulkan and is slower
  # but is extremely well tested on this generation.
  boot.kernelParams = [
    "radeon.si_support=0"
    "amdgpu.si_support=1"
  ];

  # Load amdgpu in stage 1 so the console and ly come up on the real driver
  # rather than efifb. nixos-hardware already does the equivalent for i915 via
  # hardware.intelgpu.loadInInitrd.
  boot.initrd.kernelModules = [ "amdgpu" ];

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

  # Only consulted for the X11 session; Plasma 6 defaults to Wayland.
  services.xserver.videoDrivers = [
    "amdgpu"
    "modesetting"
  ];

  # NOTE: which GPU actually drives the internal panel is decided by Apple's
  # EFI before Linux starts, and on this model that is normally the AMD part.
  # vga_switcheroo can hand the panel over to the Intel GPU at runtime
  # (/sys/kernel/debug/vgaswitcheroo/switch), which is a large battery win, but
  # doing it reliably at boot needs an apple-set-os EFI shim in the ESP. Not
  # set up here.
}
