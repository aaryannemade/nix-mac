{
  pkgs,
  hostname,
  ...
}:

{
  # X11 windowing system. Kept enabled for keymap/input infrastructure and as a
  # fallback session; Plasma itself runs on Wayland by default.
  services.xserver.enable = true;

  # ly: TUI display manager. Replaces SDDM, which plasma6 would otherwise pull
  # in. It reads sessions from the standard wayland-sessions/xsessions dirs, so
  # Plasma (Wayland) and Plasma (X11) both show up in the session picker.
  services.displayManager.ly = {
    enable = true;
    settings = {
      animation = "matrix";
      bg = "0x00000000";
      fg = "0x00FFFFFF";
      border_fg = "0x00FFFFFF";
      error_fg = "0x00FFFFFF";
      cmatrix_fg = "0x00FFFFFF";
      cmatrix_head_col = "0x00FFFFFF";
      initial_info_text = "${hostname}";
      hide_version_string = true;
      clock = "%H:%M";
    };
  };

  services.desktopManager.plasma6.enable = true;

  environment.systemPackages = with pkgs; [
    wl-clipboard
  ];
}
