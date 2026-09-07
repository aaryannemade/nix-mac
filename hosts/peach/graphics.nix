{
  config,
  lib,
  pkgs,
  ...
}:

let
  # ---- Panel routing policy -------------------------------------------------
  # Which GPU should drive the internal panel from the next boot onwards.
  #
  #   "integrated"  Intel Iris Pro 5200. Roughly 6 W cheaper at idle, because
  #                 the AMD part can then be powered down entirely.
  #   "discrete"    AMD R9 M370X. Apple's default for anything that is not
  #                 macOS, and the state a NVRAM reset returns you to.
  #
  # Changing this and rebuilding rewrites the firmware variable and takes
  # effect on the *next* boot. This is the switch to flip if the machine ever
  # comes up with a black panel: it can be done over SSH, since only the
  # display is affected, never networking. See README for the recovery path.
  panelGpu = "integrated";

  # ---- apple_set_os shim ----------------------------------------------------
  # Sits at the very front of the boot chain, tells the firmware it is booting
  # macOS so the iGPU is not powered down, then hands over to systemd-boot.
  # Both the removable-media fallback and systemd-boot's canonical path are
  # replaced: bootctl registers the latter in NVRAM, so replacing only the
  # fallback would let a fresh install silently bypass the shim. The real
  # systemd-boot lives at a separate, maintained rescue path.
  appleSetOsLoader = pkgs.callPackage ./pkgs/apple-set-os-loader.nix {
    chainloadPath = ''\EFI\BOOT\BOOTX64_SYSTEMD.EFI'';
  };

  esp = config.boot.loader.efi.efiSysMountPoint;

  # Undocumented Apple firmware variable, reverse engineered by 0xbb/gpu-switch.
  # Note it is write-only on this firmware: SetVariable is accepted but
  # GetVariable fails, so it can be set but never read back. That is why the
  # service below infers the current state from the DRM connectors instead.
  gpuPowerPrefs = "/sys/firmware/efi/efivars/gpu-power-prefs-fa4ce28d-b62f-4c99-9cc3-6815686e30f9";

  # The iGPU's fixed PCI address. Card numbering (card1/card2) depends on
  # driver probe order and is not stable across boots; the PCI address is.
  intelPci = "/sys/bus/pci/devices/0000:00:02.0";

  # ---- dGPU power ------------------------------------------------------------
  # amdgpu logs "Runtime PM not available" on this machine: its runtime PM
  # hangs off ATPX, which is a PC firmware thing. Apple uses gmux instead, so
  # the driver never gets a power domain and the card idles at full power even
  # with no connectors attached. vga_switcheroo's OFF command goes through the
  # gmux handler directly and does cut power, which is where the ~6 W comes
  # from. The cost is that DRI_PRIME offload needs the card switched back on.
  dgpuOff = pkgs.writeShellApplication {
    name = "dgpu-off";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
    ];
    text = ''
      switch=/sys/kernel/debug/vgaswitcheroo/switch

      # amdgpu registers as a switcheroo client fairly late. The switch file
      # can exist with only the Intel client in it, so wait for the discrete
      # client itself rather than just the file. Also covers resume, where the
      # file is already present but the client may not be ready yet.
      for _ in $(seq 1 60); do
        if [ -e "$switch" ] && grep -q '^[0-9]*:DIS:' "$switch"; then
          break
        fi
        sleep 1
      done

      if [ ! -e "$switch" ] || ! grep -q '^[0-9]*:DIS:' "$switch"; then
        echo "discrete GPU did not register with vga_switcheroo"
        exit 0
      fi

      # OFF powers down every client that is not currently active. If the
      # discrete card were the active one that would target the Intel GPU and
      # black out the panel, so only proceed when Intel genuinely owns it.
      if ! grep -q '^[0-9]*:IGD:+' "$switch"; then
        echo "Intel GPU is not driving the panel; refusing to power anything off"
        cat "$switch"
        exit 0
      fi

      echo OFF > "$switch"
      cat "$switch"
    '';
  };
in
{
  assertions = [
    {
      assertion = builtins.elem panelGpu [
        "integrated"
        "discrete"
      ];
      message = ''panelGpu must be either "integrated" or "discrete"'';
    }
  ];

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
  boot.kernelPackages = pkgs.linuxPackages_latest.extend (
    _final: previous: {
      # Linux 7.2 removed vb2_ops.wait_prepare/wait_finish and stopped exposing
      # string functions through indirect includes. facetimehd 0.6.13 still uses
      # the old API; remove the now-unnecessary callbacks and include string.h.
      facetimehd = previous.facetimehd.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./patches/facetimehd-linux-7.2.patch ];
      });
    }
  );

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

  # ---- Handing the panel to the Intel GPU -----------------------------------
  #
  # Out of the box this machine runs entirely on the AMD GPU and idles around
  # 27 W. Two separate firmware behaviours have to be defeated to change that,
  # and doing only one of them achieves nothing:
  #
  #   1. Apple's EFI powers the iGPU down unless it believes macOS is booting.
  #      Defeated by the apple_set_os shim below. On its own this leaves i915
  #      bound but with no eDP: "failed to retrieve link info, disabling eDP".
  #
  #   2. Independently, the firmware muxes the internal panel to the discrete
  #      GPU. Defeated by the gpu-power-prefs NVRAM variable below. On its own
  #      this gives a black screen, because of (1).
  #
  # Order matters at boot, not at install time: the shim has to have run before
  # the firmware acts on the variable.

  boot.loader.systemd-boot = {
    # bootctl refuses to touch a boot loader it does not recognise and returns
    # ESRCH for it. Since EFI/BOOT/BOOTX64.EFI is our shim rather than a copy
    # of systemd-boot, `bootctl update` would exit non-zero and fail the whole
    # rebuild the next time systemd is bumped. --graceful downgrades exactly
    # that case to a log line. It does not make bootctl skip anything it would
    # otherwise have done to systemd-boot's own copies.
    graceful = true;

    # Keep a pristine systemd-boot under a second name in EFI/BOOT. bootctl's
    # update_efi_boot_binaries() keeps every systemd-boot binary in that
    # directory current, so this copy maintains itself. It is both the normal
    # chainload target and the rescue loader. If the shim ever breaks the
    # machine, booting macOS and copying it over BOOTX64.EFI restores a working
    # NixOS boot without a live USB.
    extraFiles."EFI/BOOT/BOOTX64_SYSTEMD.EFI" =
      "${pkgs.systemd}/lib/systemd/boot/efi/systemd-bootx64.efi";

    # Runs after bootctl, so it reclaims both firmware entry points whenever
    # bootctl reinstalls systemd-boot. The canonical path matters because
    # bootctl may register it as "Linux Boot Manager" in NVRAM; without the
    # second copy, that entry would bypass apple_set_os and can produce a black
    # panel with an integrated gpu-power-prefs value.
    #
    # Keep the shim installed even in discrete mode. Removing it before a
    # gpu-power-prefs write has been proven successful is not failure-atomic:
    # stale integrated policy plus no shim means a black panel next boot.
    # Keeping the iGPU available is harmless when the panel is on AMD and gives
    # a reliable recovery path if the firmware variable write fails.
    extraInstallCommands = ''
      shim=${appleSetOsLoader}/share/apple-set-os-loader/apple-set-os-loader.efi
      ${pkgs.coreutils}/bin/install -m 0444 "$shim" \
        ${esp}/EFI/BOOT/BOOTX64.EFI
      ${pkgs.coreutils}/bin/install -m 0444 "$shim" \
        ${esp}/EFI/systemd/systemd-bootx64.efi
    '';
  };

  systemd.services.apple-gpu-power-prefs = {
    description = "Select the GPU that Apple's firmware wires the panel to";
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathIsReadWrite = "/sys/firmware/efi/efivars";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [
      pkgs.coreutils
      pkgs.e2fsprogs
    ];
    script = ''
      # The variable cannot be read back, so use the hardware as the source of
      # truth: if the Intel GPU has an eDP connector, it owns the panel.
      edp=(${intelPci}/drm/card*/card*-eDP-*)
      if [ -e "''${edp[0]}" ]; then
        current=integrated
      else
        current=discrete
      fi

      if [ "$current" = "${panelGpu}" ]; then
        echo "panel is already on the $current GPU, leaving NVRAM untouched"
        exit 0
      fi

      echo "panel is on the $current GPU, requesting ${panelGpu} for next boot"

      # efivarfs marks variables immutable to stop careless writes.
      chattr -i ${gpuPowerPrefs} 2>/dev/null || true

      # Layout is 4 bytes of EFI attributes (NV|BS|RT) followed by the value,
      # written in a single write() as efivarfs requires. The firmware ORs in
      # its own bit 31, which is why other Apple variables read back as
      # 0x80000007. Values are 1 = integrated, 0 = discrete.
      ${
        if panelGpu == "integrated" then
          ''printf '\x07\x00\x00\x00\x01\x00\x00\x00' > ${gpuPowerPrefs}''
        else
          ''printf '\x07\x00\x00\x00\x00\x00\x00\x00' > ${gpuPowerPrefs}''
      }

      echo "done; reboot for this to take effect"
    '';
  };

  systemd.services.dgpu-off = lib.mkIf (panelGpu == "integrated") {
    description = "Power down the discrete GPU through vga_switcheroo";
    wantedBy = [ "multi-user.target" ];
    after = [ "apple-gpu-power-prefs.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = lib.getExe dgpuOff;
    };
  };

  # gmux re-powers the discrete GPU across a suspend/resume cycle, so the same
  # check has to run again on the way back up.
  powerManagement.resumeCommands = lib.mkIf (panelGpu == "integrated") ''
    ${lib.getExe dgpuOff} || true
  '';
}
