{ pkgs, ... }:

{
  # X11 windowing system. Kept enabled for keymap/input infrastructure and as a
  # fallback session; Plasma itself runs on Wayland by default.
  services.xserver.enable = true;

  # SDDM is KDE's display manager and integrates cleanly with Plasma's
  # sessions and HiDPI handling. Keep SDDM itself on its mature X11 backend;
  # Plasma's Wayland session remains available after login.
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = false;
  };

  services.desktopManager.plasma6.enable = true;

  environment.systemPackages = with pkgs; [
    wl-clipboard
  ];
}
