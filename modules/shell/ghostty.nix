{ ... }:

{
  programs.ghostty.enable = true;

  # Cover CLI programs that predate the XDG default-terminal specification.
  home.sessionVariables.TERMINAL = "ghostty";

  # The value is Ghostty's desktop file ID, not its binary name.
  xdg.terminal-exec = {
    enable = true;
    settings.default = [ "com.mitchellh.ghostty.desktop" ];
  };
}
