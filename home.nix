{
  config,
  username,
  homeDirectory,
  ...
}:

{
  imports = [
    ./modules
  ];

  home.username = username;
  home.homeDirectory = homeDirectory;
  home.stateVersion = "26.05";

  # Create standard home directories on activation.
  xdg.userDirs = {
    enable = true;
    setSessionVariables = false;
    createDirectories = true;
    extraConfig = {
      screenshots = "${config.home.homeDirectory}/Pictures/screenshots";
      screenrecordings = "${config.home.homeDirectory}/Videos/screenrecordings";
      trash = "${config.home.homeDirectory}/Trash";
    };
  };
}
