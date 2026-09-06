# nix-mac

NixOS config for a MacBook Pro 15" (Mid 2015, **MacBookPro11,5**). Single host:
`peach`.

Structure follows [nix-desktop](https://github.com/aaryannemade/nix-desktop):

```
flake.nix              inputs + nixosConfigurations
configuration.nix      common system config (nix settings, stateVersion)
home.nix               home-manager entry point
hosts/
  default.nix          the single nixosSystem definition
  peach/
    configuration.nix  host entry point
    hardware-configuration.nix
    graphics.nix       dual GPU
    peripherals.nix    wifi firmware, webcam
    power.nix          power profiles, thermals, fans
system/                generic system policy
modules/
  browsers/            librewolf
  shell/               zsh
```

`system/` is machine-agnostic policy; anything specific to this laptop's
hardware lives under `hosts/peach/`.

## What's enabled

- zsh (system shell + home-manager config: oh-my-zsh, autosuggestions, syntax highlighting)
- LibreWolf (default browser, VA-API hardware decode, persistent sessions)
- SDDM display manager, KDE Plasma 6
- PipeWire, NetworkManager, Bluetooth, systemd-boot
- Radeon R9 M370X on `amdgpu`, Iris Pro 5200 on `i915`
- FaceTime HD webcam (`facetimehd`)
- power-profiles-daemon, thermald, mbpfan

## Hardware notes

Machine-specific decisions, and why.

**Wi-Fi is *not* the unfree Broadcom driver.** This model has a BCM43602
(`14e4:43ba`), handled by the in-tree `brcmfmac` module with firmware from
`hardware.enableRedistributableFirmware`. The unfree `broadcom_sta` (`wl`)
driver supports BCM4360 and older and does not claim 43602 — installing it
gives you *no* wireless. nixpkgs' own `hardware/network/broadcom-43xx.nix` is a
single line enabling redistributable firmware, nothing more.

The regulatory domain is pinned to India (`IN`) in `peripherals.nix`. Leaving
cfg80211 at its default world domain (`00`) prevented the BCM43602 from finding
the `vite` 5 GHz network; `iw reg set IN` confirmed the fix on the machine.

**The R9 M370X is GCN 1.0.** PCI `1002:6821`, "Venus XT", a Cape Verde rebrand,
i.e. Southern Islands. The config uses `linuxPackages_latest`, matching the
graphical installer generation where the internal panel is known to work.
Kernel 7.2 selects `amdgpu` for this device without override parameters. The
stable 6.18 kernel initialized the GPU but failed Atomic Mode Setting and left
the internal panel black, so do not force this machine back to that kernel.

**GPU switching is not configured.** Apple's EFI picks which GPU drives the
internal panel before Linux starts, normally the AMD one. Running on the Intel
iGPU is a large battery win but needs an `apple-set-os` EFI shim in the ESP to
do reliably. Not set up.

**nixos-hardware's 11-5 profile has a gap**: it imports the generic Intel CPU
profile rather than the Haswell one (which 11-4 gets right), so it would
install `intel-media-driver` — Broadwell and newer only. `graphics.nix` pins
`hardware.intelgpu.vaapiDriver = "intel-vaapi-driver"` to correct this.

**systemd-boot, not GRUB** (unlike nix-desktop). GRUB's `efiSupport` path is
unreliable on 2015-era Apple EFI.

**Unfree**: only `facetimehd-firmware`, allowlisted in
`hosts/peach/peripherals.nix` via the `my.unfreePackages` option defined in
`system/unfree.nix`. Redistributable firmware (`linux-firmware`) is not unfree
and needs no entry.

## Install

From the minimal NixOS ISO, booted on the MacBook (hold Option at the chime,
pick the EFI Boot USB).

1. Partition. GPT, ESP + root. The labels matter for the placeholder hardware
   config:

   ```sh
   parted /dev/sda -- mklabel gpt
   parted /dev/sda -- mkpart ESP fat32 1MiB 1GiB
   parted /dev/sda -- set 1 esp on
   parted /dev/sda -- mkpart root ext4 1GiB 100%

   mkfs.fat -F 32 -n boot /dev/sda1
   mkfs.ext4 -L nixos /dev/sda2
   ```

2. Mount:

   ```sh
   mount /dev/disk/by-label/nixos /mnt
   mkdir -p /mnt/boot
   mount -o umask=077 /dev/disk/by-label/boot /mnt/boot
   ```

3. Clone and generate the real hardware config:

   ```sh
   nix-shell -p git
   git clone https://github.com/aaryannemade/nix-mac /mnt/etc/nixos-mac
   nixos-generate-config --root /mnt --show-hardware-config \
     > /mnt/etc/nixos-mac/hosts/peach/hardware-configuration.nix
   ```

   `hosts/peach/hardware-configuration.nix` in git is a **placeholder**. Always
   overwrite it with the generated one, then commit it.

4. Install:

   ```sh
   nixos-install --flake /mnt/etc/nixos-mac#peach
   ```

5. After first boot, move the repo somewhere sane and rebuild from there:

   ```sh
   sudo mv /etc/nixos-mac ~/nix-mac && sudo chown -R aaryan:users ~/nix-mac
   nrs   # alias for: sudo nixos-rebuild switch --flake ~/nix-mac#peach
   ```

## Verifying the hardware after install

```sh
lspci -k | grep -A3 VGA        # amdgpu bound to 1002:6821, i915 to the Intel
lsmod | grep -E 'brcmfmac|facetimehd|applesmc'
vainfo                         # VA-API
vulkaninfo --summary           # radv should appear
systemctl status mbpfan thermald power-profiles-daemon
cat /sys/kernel/debug/vgaswitcheroo/switch   # (as root) which GPU has the panel
```

## Not handled yet

- Keyboard backlight control
- Suspend/hibernate tuning beyond the defaults
- Anything beyond the base desktop: browsers, editors, dev tooling
